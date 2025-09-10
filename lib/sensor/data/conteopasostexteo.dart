import 'package:proyecto_imu_v1_3/sensor/data/fusion_y_acortamiento_datos.dart';
import 'package:proyecto_imu_v1_3/sensor/data/heading_processor.dart';
import 'package:proyecto_imu_v1_3/utils/position_calculator.dart';
import 'Estimador_distancia_pasos.dart';
import 'dart:math';

class ConteoPasosTexteando {
  final acortamientoDatos = ProcesamientoEventos();
  final controladorDifuso = ControladorDifusoK();
  final headingProcessor = HeadingProcessor();

  /// Getter para acceder a los azimuth promedio de cada paso detectado
  List<double> get averageAzimuthPerStep =>
      headingProcessor.averageAzimuthPerStep;

  /// Getter para acceder a los patrones de heading (5 valores) de cada paso detectado
  List<List<double>> get headingPatternsPerStep =>
      headingProcessor.headingPatternsPerStep;

  /// Reinicia los datos de azimuth para una nueva sesión
  void resetAzimuthData() {
    headingProcessor.resetAzimuthData();
  }

  /// Calcula el recorrido de posiciones usando las distancias y azimuth de los pasos
  ///
  /// [matrizPasos] Matriz con datos de pasos donde:
  /// - Fila 1: Duraciones de pasos
  /// - Fila 2: Longitudes de pasos
  ///
  /// Retorna Map con:
  /// - 'coordenadas': Matriz de coordenadas [x, y]
  /// - 'posicionFinal': Posición final {x, y, distancia}
  /// - 'distanciaTotal': Distancia total recorrida
  Map<String, dynamic> calcularRecorridoPosicion(
    List<List<double>> matrizPasos,
  ) {
    final distancias = <double>[];
    final azimuthList = headingProcessor.averageAzimuthPerStep;

    // Extraer distancias válidas de la matriz de pasos
    if (matrizPasos.length >= 3 && matrizPasos[2].isNotEmpty) {
      final contadorPasos =
          matrizPasos[0][1].toInt(); // Número de pasos detectados

      for (int i = 0; i < contadorPasos && i < matrizPasos[2].length; i++) {
        distancias.add(matrizPasos[2][i]);
      }
    }

    // Validar que tengamos la misma cantidad de distancias y azimuth
    final minLength =
        distancias.length < azimuthList.length
            ? distancias.length
            : azimuthList.length;

    if (minLength == 0) {
      return {
        'coordenadas': [<double>[], <double>[]],
        'posicionFinal': {'x': 0.0, 'y': 0.0, 'distancia': 0.0},
        'distanciaTotal': 0.0,
      };
    }

    // Tomar solo los datos disponibles
    final distanciasValidas = distancias.take(minLength).toList();
    final azimuthValidos = azimuthList.take(minLength).toList();

    // Calcular recorrido usando PositionCalculator
    final coordenadas = PositionCalculator.calcularRecorrido([
      distanciasValidas,
      azimuthValidos,
    ]);

    // Obtener información adicional
    final posicionFinal = PositionCalculator.obtenerPosicionFinal(coordenadas);
    final distanciaTotal = PositionCalculator.calcularDistanciaTotal(
      distanciasValidas,
    );

    return {
      'coordenadas': coordenadas,
      'posicionFinal': posicionFinal,
      'distanciaTotal': distanciaTotal,
    };
  }

  /// Obtiene información completa del recorrido incluyendo estadísticas
  ///
  /// [matrizPasos] Matriz con datos de pasos
  ///
  /// Retorna Map con información detallada del recorrido
  Map<String, dynamic> obtenerInformacionCompleta(
    List<List<double>> matrizPasos,
  ) {
    final recorrido = calcularRecorridoPosicion(matrizPasos);
    final azimuthList = headingProcessor.averageAzimuthPerStep;
    final contadorPasos =
        matrizPasos.length >= 1 && matrizPasos[0].length >= 2
            ? matrizPasos[0][1].toInt()
            : 0;

    return {
      ...recorrido,
      'pasos': {
        'cantidad': contadorPasos,
        'azimuthPromedio':
            azimuthList.isNotEmpty
                ? azimuthList.reduce((a, b) => a + b) / azimuthList.length
                : 0.0,
        'patrones': headingProcessor.headingPatternsPerStep,
      },
    };
  }

  void procesar(
    List<List<double>> matrizOrdenada,
    List<List<double>> matrizDatosRecientes,
    List<List<double>> matrizPasos,
    List<List<double>> matrizSecuenciasRevisar,
    List<double> unionFiltradoRecortadoTotal,
    List<double> unionFiltradoRecortadoTotal2,
    int ventanaTiempo,
    List<List<double>> matrizGyro,
    List<double> listaTiemposRestados,
  ) {
    if (matrizOrdenada.isEmpty || matrizOrdenada[0].isEmpty) return;

    final n = matrizOrdenada[0].length + 4;
    List<List<double>> matrizDatosExtendida = List.generate(
      4, // Cambiado de 3 a 4 para incluir heading filtrado
      (_) => List.filled(n, 0.0),
    );

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        // Cambiado de 3 a 4 para incluir heading
        matrizDatosExtendida[j][i] = matrizDatosRecientes[j][i];
      }
    }

    for (int i = 4; i < n; i++) {
      // matrizOrdenada siempre tiene 4 filas desde sensor processor stage 5
      for (int j = 0; j < 4; j++) {
        final indexOrigen = i - 4;
        if (indexOrigen < matrizOrdenada[j].length) {
          matrizDatosExtendida[j][i] = matrizOrdenada[j][indexOrigen];
        }
      }
    }

    final (
      simbolosFilt,
      magnitudesFilt,
      tiemposFilt,
      headingFilt,
    ) = acortamientoDatos.filtrarSimbolosCeroConHeading(
      matrizDatosExtendida[0],
      matrizDatosExtendida[1],
      matrizDatosExtendida[2],
      matrizDatosExtendida[3],
    );

    var matrizDatosAcortada = acortamientoDatos
        .procesarSimbolosConsecutivosConHeading(
          simbolosFilt,
          magnitudesFilt,
          tiemposFilt,
          headingFilt,
        );

    matrizDatosAcortada = _filtrarPrimerCruceConTiempo(matrizDatosAcortada);

    final totalFilas1 = matrizDatosExtendida[0].length - 4;
    final totalFilas = matrizDatosAcortada[0].length;
    if (totalFilas1 < 4) {
      int faltan = 4 - totalFilas1;
      for (int i = 0; i < 4; i++) {
        if (i < faltan) {
          matrizDatosRecientes[0][i] = 0;
          matrizDatosRecientes[1][i] = 0;
          matrizDatosRecientes[2][i] = 0;
          matrizDatosRecientes[3][i] = 0; // Nueva fila para heading
        } else {
          int idx = totalFilas - totalFilas1 + (i - faltan);
          if (idx >= 0 &&
              idx < totalFilas &&
              idx < matrizDatosAcortada[0].length &&
              idx < matrizDatosAcortada[1].length &&
              idx < matrizDatosAcortada[2].length) {
            if (matrizDatosAcortada[2][idx] < -50) {
              matrizDatosRecientes[0][i] = 0.0;
            } else {
              matrizDatosRecientes[0][i] = matrizDatosAcortada[0][idx];
            }
            matrizDatosRecientes[1][i] = matrizDatosAcortada[1][idx];
            matrizDatosRecientes[2][i] =
                (ventanaTiempo - matrizDatosAcortada[2][idx]) * -1;

            // Agregar datos de heading acortados y correlacionados a la cuarta fila
            if (matrizDatosAcortada.length >= 4 &&
                idx < matrizDatosAcortada[3].length) {
              matrizDatosRecientes[3][i] = matrizDatosAcortada[3][idx];
            } else {
              matrizDatosRecientes[3][i] = 0.0;
            }
          } else {
            matrizDatosRecientes[0][i] = 0;
            matrizDatosRecientes[1][i] = 0;
            matrizDatosRecientes[2][i] = 0;
            matrizDatosRecientes[3][i] = 0; // Nueva fila para heading
          }
        }
      }
    } else {
      for (int i = 0; i < 4; i++) {
        int idx = totalFilas - 4 + i;

        // Validación adicional para evitar range errors
        if (idx < 0 ||
            idx >= totalFilas ||
            idx >= matrizDatosAcortada[0].length ||
            idx >= matrizDatosAcortada[1].length ||
            idx >= matrizDatosAcortada[2].length) {
          matrizDatosRecientes[0][i] = 0.0;
          matrizDatosRecientes[1][i] = 0.0;
          matrizDatosRecientes[2][i] = 0.0;
          matrizDatosRecientes[3][i] = 0.0;
          continue;
        }

        if (matrizDatosAcortada[2][idx] < -65) {
          matrizDatosRecientes[0][i] = 0.0;
        } else {
          matrizDatosRecientes[0][i] = matrizDatosAcortada[0][idx];
        }
        matrizDatosRecientes[1][i] = matrizDatosAcortada[1][idx];
        matrizDatosRecientes[2][i] =
            (ventanaTiempo - matrizDatosAcortada[2][idx]) * -1;

        // Agregar datos de heading acortados y correlacionados a la cuarta fila
        if (matrizDatosAcortada.length >= 4 &&
            idx < matrizDatosAcortada[3].length) {
          matrizDatosRecientes[3][i] = matrizDatosAcortada[3][idx];
        } else {
          matrizDatosRecientes[3][i] = 0.0;
        }
      }
    }
    unionFiltradoRecortadoTotal.addAll(matrizDatosAcortada[0]);
    unionFiltradoRecortadoTotal.add(0.0);
    unionFiltradoRecortadoTotal2.addAll(matrizDatosAcortada[2]);
    unionFiltradoRecortadoTotal2.add(0.0);

    if (matrizDatosAcortada[0].length < 5) {
      matrizPasos[0][0] = 0.0;
      return;
    }

    int filasM = matrizDatosAcortada[0].length - 4;
    int contadorPasos = 0;
    double longitudPaso = 0;
    int indicadorPaso = matrizPasos[0][0].toInt();

    for (int i = 0; i < filasM; i++) {
      // Validación adicional para evitar range error
      if (i + 4 >= matrizDatosAcortada[0].length ||
          i + 4 >= matrizDatosAcortada[1].length ||
          i + 4 >= matrizDatosAcortada[2].length) {
        break; // Salir del bucle si no hay suficientes elementos
      }

      List<double> secuencia = [
        matrizDatosAcortada[0][i],
        matrizDatosAcortada[0][i + 1],
        matrizDatosAcortada[0][i + 2],
        matrizDatosAcortada[0][i + 3],
        matrizDatosAcortada[0][i + 4],
      ];

      matrizSecuenciasRevisar.add(List.from(secuencia));
      if (secuencia[2] == 1 && secuencia[3] == 1 && secuencia[4] == 1) {
        indicadorPaso = 0;
        matrizPasos[0][0] = 0.0;
        continue;
      }

      if (secuencia[0] == 1 && secuencia[2] == 1 && secuencia[4] == 1) {
        if ((secuencia[1] == 2 && secuencia[3] == 3) ||
            (secuencia[1] == 3 && secuencia[3] == 2)) {
          double tiempo1 = matrizDatosAcortada[2][i];
          double tiempo2 = matrizDatosAcortada[2][i + 4];
          double amplitud1 = matrizDatosAcortada[1][i + 1];
          double amplitud2 = matrizDatosAcortada[1][i + 3];

          double diferenciaTiempo = (tiempo2 - tiempo1).abs();
          double diferenciaAmplitud = amplitud1.abs() + amplitud2.abs();

          // Validar que la diferencia de amplitud sea positiva y finita
          if (diferenciaAmplitud <= 0 || !diferenciaAmplitud.isFinite) {
            continue; // Saltar si la diferencia no es válida
          }

          double kDinamico;
          if (secuencia[1] == 2 && secuencia[3] == 3) {
            if (indicadorPaso == 0) {
              indicadorPaso = 1;
              matrizPasos[0][0] = 1.0;
            }
            if (indicadorPaso == 1) {
              listaTiemposRestados.add(tiempo1);
              listaTiemposRestados.add(tiempo2);
              kDinamico = controladorDifuso.calcularK(
                diferenciaTiempo,
                diferenciaAmplitud,
              );

              longitudPaso = kDinamico * pow(diferenciaAmplitud, 0.25);

              // // Validar que longitudPaso sea finita y razonable
              // if (!longitudPaso.isFinite ||
              //     longitudPaso <= 0 ||
              //     longitudPaso > 5.0) {
              //   longitudPaso = 0.5; // Valor por defecto razonable (50 cm)
              // }

              matrizPasos[1][contadorPasos] = diferenciaTiempo;
              matrizPasos[2][contadorPasos] = longitudPaso;

              // Procesar azimuth para el paso detectado usando HeadingProcessor
              headingProcessor.procesarAzimuthPaso(
                matrizDatosAcortada,
                i,
                tiempo1,
                tiempo2,
              );

              contadorPasos++;
            }
          }

          if (secuencia[1] == 3 && secuencia[3] == 2) {
            if (indicadorPaso == 0) {
              indicadorPaso = 2;
              matrizPasos[0][0] = 2.0;
            }
            if (indicadorPaso == 2) {
              listaTiemposRestados.add(tiempo1);
              listaTiemposRestados.add(tiempo2);
              kDinamico = controladorDifuso.calcularK(
                diferenciaTiempo,
                diferenciaAmplitud,
              );

              longitudPaso = kDinamico * pow(diferenciaAmplitud, 0.25);

              // // Validar que longitudPaso sea finita y razonable
              // if (!longitudPaso.isFinite ||
              //     longitudPaso <= 0 ||
              //     longitudPaso > 5.0) {
              //   longitudPaso = 0.5; // Valor por defecto razonable (50 cm)
              // }

              matrizPasos[1][contadorPasos] = diferenciaTiempo;
              matrizPasos[2][contadorPasos] = longitudPaso;

              // Procesar azimuth para el paso detectado usando HeadingProcessor
              headingProcessor.procesarAzimuthPaso(
                matrizDatosAcortada,
                i,
                tiempo1,
                tiempo2,
              );

              contadorPasos++;
            }
          }
        }
      }
    }

    matrizPasos[0][1] = contadorPasos.toDouble();
    matrizPasos[0][2] += contadorPasos.toDouble();

    // Validar que longitudPaso sea finita antes de acumular
    if (longitudPaso.isFinite && longitudPaso > 0) {
      matrizPasos[0][3] += longitudPaso;
    }

    // Validar que el total acumulado sea finito
    if (!matrizPasos[0][3].isFinite) {
      matrizPasos[0][3] = 0.0; // Resetear si se vuelve infinito
    }
  }

  // Método privado para filtrar cruces consecutivos
  List<List<double>> _filtrarPrimerCruceConTiempo(List<List<double>> matriz) {
    // Si la matriz está vacía o no tiene suficientes elementos para una secuencia,
    // la devolvemos sin cambios para evitar errores.
    if (matriz.isEmpty || matriz[0].length < 2) {
      return matriz;
    }

    // Determinar si tenemos 3 o 4 filas
    final int numFilas = matriz.length;

    // Lista para almacenar el resultado del filtrado.
    List<List<double>> resultado = List.generate(numFilas, (_) => <double>[]);

    int i = 0; // Índice para recorrer la matriz.
    while (i < matriz[0].length) {
      // Verificamos si hay al menos dos '1's consecutivos.
      // La condición `i + 1 < matriz[0].length` previene un error de rango.
      if (i + 1 < matriz[0].length &&
          matriz[0][i] == 1 &&
          matriz[0][i + 1] == 1) {
        // --- LÓGICA SIMPLIFICADA ---
        // Siempre seleccionamos los datos correspondientes al segundo '1' de la secuencia.
        for (int fila = 0; fila < numFilas; fila++) {
          resultado[fila].add(matriz[fila][i + 1]);
        }

        // Avanzamos el índice en 2 para saltar el par de '1's que acabamos de procesar.
        i += 2;

        // Después, avanzamos sobre cualquier otro '1' consecutivo para ignorarlos.
        // Esto asegura que de una secuencia larga (ej: 1, 1, 1, 1), solo nos
        // quedemos con el segundo y saltemos el resto.
        while (i < matriz[0].length && matriz[0][i] == 1) {
          i++;
        }
      } else {
        // Si el elemento actual no es un '1' o no inicia una secuencia,
        // simplemente lo agregamos al resultado y avanzamos al siguiente.
        for (int fila = 0; fila < numFilas; fila++) {
          resultado[fila].add(matriz[fila][i]);
        }
        i++;
      }
    }

    return resultado;
  }

  bool _esPasoValidoConGyro(
    List<List<double>> matrizGyro,
    List<List<double>> matrizDatosAcortada,
    int indicePaso,
  ) {
    const List<int> indicesEventos = [1, 3];
    const double umbralTiempo = 11;

    // Validación de límites para evitar range error
    if (matrizGyro.isEmpty ||
        matrizGyro[0].isEmpty ||
        matrizGyro.length < 2 ||
        matrizDatosAcortada.isEmpty ||
        matrizDatosAcortada.length < 3 ||
        indicePaso < 0) {
      return true; // Retornar true si no hay datos suficientes para validar
    }

    // Validar que matrizGyro tenga al menos 2 filas y que la segunda fila no esté vacía
    if (matrizGyro.length < 2 || matrizGyro[1].isEmpty) {
      return true;
    }

    for (int j = 0; j < matrizGyro[0].length; j++) {
      // Validar que j esté dentro de los límites para ambas filas
      if (j >= matrizGyro[1].length) {
        continue;
      }

      for (int k in indicesEventos) {
        // Validar que indicePaso + k esté dentro de los límites
        if (indicePaso + k >= matrizDatosAcortada[2].length ||
            indicePaso + k < 0) {
          continue; // Saltar esta iteración si está fuera de límites
        }

        double diferencia =
            (matrizGyro[1][j] - matrizDatosAcortada[2][indicePaso + k]).abs();
        if (diferencia < umbralTiempo) {
          return false;
        }
      }
    }
    return true;
  }
}
