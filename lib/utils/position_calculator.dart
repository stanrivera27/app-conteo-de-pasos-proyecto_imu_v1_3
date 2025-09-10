import 'dart:math';

/// Utilidad para calcular el recorrido de posiciones basado en distancias y ángulos
/// Convierte coordenadas polares a cartesianas y acumula la posición
class PositionCalculator {
  /// Calcula el recorrido de las distancias y los ángulos
  ///
  /// [dydUnidas] Matriz de 2 filas donde:
  /// - Fila 0: Distancias de cada paso
  /// - Fila 1: Ángulos/azimuth en grados
  ///
  /// Retorna matriz de 2 filas con:
  /// - Fila 0: Coordenadas X acumuladas
  /// - Fila 1: Coordenadas Y acumuladas
  static List<List<double>> calcularRecorrido(List<List<double>> dydUnidas) {
    // Validación más robusta de entrada
    if (dydUnidas.isEmpty ||
        dydUnidas.length < 2 ||
        dydUnidas[0].isEmpty ||
        dydUnidas[1].isEmpty) {
      return [[], []]; // Retornar matriz vacía si los datos no son válidos
    }

    // Verificar que ambas filas tengan la misma longitud
    if (dydUnidas[0].length != dydUnidas[1].length) {
      return [[], []]; // Retornar matriz vacía si las dimensiones no coinciden
    }

    final int length = dydUnidas[0].length;

    // Matriz para almacenar coordenadas X e Y
    List<List<double>> xy = List.generate(2, (_) => List.filled(length, 0.0));

    // Array para almacenar ángulos en radianes
    List<double> theta = List.filled(length, 0.0);

    // Validación adicional antes de acceder a los índices
    if (length > 0 && dydUnidas[0].isNotEmpty && dydUnidas[1].isNotEmpty) {
      // Paso directamente la primera distancia y el primer azimuth
      xy[0][0] = dydUnidas[0][0]; // Primera distancia
      xy[1][0] = dydUnidas[1][0]; // Primer azimuth
    }

    int contCiclos = 1;

    // Filtrar valores no cero y copiar a la matriz de trabajo
    for (int n = 1; n < length; n++) {
      // Validación adicional para evitar range errors
      if (n < dydUnidas[0].length &&
          n < dydUnidas[1].length &&
          contCiclos < xy[0].length &&
          contCiclos < xy[1].length) {
        if (dydUnidas[0][n] != 0) {
          xy[0][contCiclos] = dydUnidas[0][n];
          xy[1][contCiclos] = dydUnidas[1][n]; // Sin restar el primer azimuth
          contCiclos++;
        }
      }
    }

    // Convertir de coordenadas polares a cartesianas
    for (int n = 0; n < length; n++) {
      // Validación antes de acceso a arrays
      if (n < xy[0].length && n < xy[1].length && n < theta.length) {
        // Convertir grados a radianes
        double angle = xy[1][n];

        // Validar que el ángulo sea finito
        if (!angle.isFinite) {
          angle = 0.0;
        }

        theta[n] = angle * pi / 180;

        // Guardar distancia temporal
        double rAux = xy[0][n];

        // Validar que la distancia sea finita
        if (!rAux.isFinite) {
          rAux = 0.0;
        }

        // Calcular coordenadas cartesianas
        double xCoord = (-1) * rAux * cos(theta[n]);
        double yCoord = rAux * sin(theta[n]);

        // Validar que las coordenadas sean finitas
        xy[0][n] = xCoord.isFinite ? xCoord : 0.0;
        xy[1][n] = yCoord.isFinite ? yCoord : 0.0;
      }
    }

    // Acumular posiciones para obtener el recorrido total
    for (int n = 1; n < length; n++) {
      // Validación antes de acceso a arrays y al índice anterior
      if (n < xy[0].length &&
          n < xy[1].length &&
          (n - 1) >= 0 &&
          (n - 1) < xy[0].length &&
          (n - 1) < xy[1].length) {
        if (xy[0][n] != 0) {
          xy[0][n] = xy[0][n] + xy[0][n - 1]; // X acumulada
          xy[1][n] = xy[1][n] + xy[1][n - 1]; // Y acumulada
        }
      }
    }

    return xy;
  }

  /// Versión simplificada que acepta listas separadas de distancias y ángulos
  ///
  /// [distancias] Lista de distancias de cada paso
  /// [angulos] Lista de ángulos/azimuth en grados
  ///
  /// Retorna un Map con las coordenadas:
  /// - 'x': Lista de coordenadas X acumuladas
  /// - 'y': Lista de coordenadas Y acumuladas
  static Map<String, List<double>> calcularRecorridoSimple(
    List<double> distancias,
    List<double> angulos,
  ) {
    if (distancias.isEmpty ||
        angulos.isEmpty ||
        distancias.length != angulos.length) {
      return {'x': <double>[], 'y': <double>[]};
    }

    // Crear matriz temporal
    final dydUnidas = [
      List<double>.from(distancias),
      List<double>.from(angulos),
    ];

    // Calcular recorrido
    final resultado = calcularRecorrido(dydUnidas);

    return {'x': resultado[0], 'y': resultado[1]};
  }

  /// Calcula la distancia total recorrida
  ///
  /// [distancias] Lista de distancias de cada paso
  ///
  /// Retorna la suma total de distancias válidas (no cero)
  static double calcularDistanciaTotal(List<double> distancias) {
    double total = 0.0;
    for (double distancia in distancias) {
      if (distancia != 0) {
        total += distancia;
      }
    }
    return total;
  }

  /// Obtiene la posición final del recorrido
  ///
  /// [recorrido] Resultado de calcularRecorrido()
  ///
  /// Retorna un Map con la posición final:
  /// - 'x': Coordenada X final
  /// - 'y': Coordenada Y final
  /// - 'distancia': Distancia desde el origen
  static Map<String, double> obtenerPosicionFinal(
    List<List<double>> recorrido,
  ) {
    // Validación más robusta
    if (recorrido.isEmpty ||
        recorrido.length < 2 ||
        recorrido[0].isEmpty ||
        recorrido[1].isEmpty) {
      return {'x': 0.0, 'y': 0.0, 'distancia': 0.0};
    }

    // Verificar que ambas filas tengan la misma longitud
    if (recorrido[0].length != recorrido[1].length) {
      return {'x': 0.0, 'y': 0.0, 'distancia': 0.0};
    }

    // Encontrar la última posición válida (no cero)
    double xFinal = 0.0;
    double yFinal = 0.0;

    final minLength =
        recorrido[0].length < recorrido[1].length
            ? recorrido[0].length
            : recorrido[1].length;

    for (int i = minLength - 1; i >= 0; i--) {
      // Validación adicional para evitar range errors
      if (i >= 0 && i < recorrido[0].length && i < recorrido[1].length) {
        if (recorrido[0][i] != 0 || recorrido[1][i] != 0) {
          xFinal = recorrido[0][i];
          yFinal = recorrido[1][i];
          break;
        }
      }
    }

    // Calcular distancia desde el origen
    double distanciaDesdeOrigen = sqrt(xFinal * xFinal + yFinal * yFinal);

    // Validar que la distancia sea finita
    if (!distanciaDesdeOrigen.isFinite) {
      distanciaDesdeOrigen = 0.0;
    }

    return {'x': xFinal, 'y': yFinal, 'distancia': distanciaDesdeOrigen};
  }
}
