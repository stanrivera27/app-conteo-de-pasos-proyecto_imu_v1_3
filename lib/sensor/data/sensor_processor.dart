import 'package:proyecto_imu_v1_3/sensor/data/low_pass_filter.dart';
import 'package:proyecto_imu_v1_3/sensor/data/clasificador_de_datos.dart';
import 'package:proyecto_imu_v1_3/sensor/data/fusion_y_acortamiento_datos.dart';
import 'package:proyecto_imu_v1_3/sensor/data/conteopasostexteo.dart';

// --- MEJORA 1: Clase dedicada a agrupar todos los datos de una única lectura ---
/// Representa una única captura de datos del sensor en un instante de tiempo.
class SensorReading {
  final double accMagnitude;
  final double gyroMagnitude;
  final double heading;

  // Datos resultantes del filtrado en tiempo real
  final double accFiltered;
  final double accFiltered2ndOrder;
  final double accFiltered4thOrder;
  final double gyroFiltered;

  SensorReading({
    required this.accMagnitude,
    required this.gyroMagnitude,
    required this.heading,
    required this.accFiltered,
    required this.accFiltered2ndOrder,
    required this.accFiltered4thOrder,
    required this.gyroFiltered,
  });
}

// --- Clase Principal Refactorizada ---
class DataProcessor {
  // Instancias de clases de procesamiento
  final ConteoPasosTexteando conteoPasos = ConteoPasosTexteando();
  final _acortaFusionaDatos = ProcesamientoEventos();

  // Filtros en tiempo real
  final StreamingFilter _accFilter = StreamingFilter(cutoffHz: 2.5, fs: 125);
  final StreamingFilter _gyroFilter = StreamingFilter(cutoffHz: 4, fs: 125);
  final StreamingFilter2ndOrder _accFilter2ndOrder = StreamingFilter2ndOrder(
    cutoffHz: 2.5,
    fs: 125,
  );
  final StreamingFilter4thOrder _accFilter4thOrder = StreamingFilter4thOrder(
    cutoffHz: 2.5,
    fs: 125,
  );

  // --- MEJORA 2: Usar una única lista de objetos en lugar de múltiples listas paralelas ---
  // Esta lista almacena el historial completo de todas las lecturas.
  final List<SensorReading> readings = [];

  // Parámetros de configuración
  final int ventanaTiempo = 125; // 125 muestras por ventana de análisis
  final int desfase = 25; // Desfase para ciertas señales
  int indiceInicio = 0; // Índice de inicio de la próxima ventana a procesar

  // Getter para mantener compatibilidad con la UI que usa `index`
  int get index => readings.length;

  // Umbrales
  double umbralGyroPico = 1;
  double umbralPico = 0.92;
  double umbralPicoSinFiltrar = 1.2;
  double umbralValle = -0.7;
  double umbralValleSinFiltrar = -0.6;

  // --- Listas reincorporadas según solicitud ---
  // Estas listas acumulan datos a lo largo del tiempo, como en la versión original.
  List<double> accMagnitudeListDesfasada = [];
  List<double> gyroMagnitudeListDesfasada = [];
  List<double> historialFiltrado = [];
  List<double> ventanaGyroXYZFiltradaList = [];
  List<List<double>> matrizordenada = [
    [],
    [],
    [],
    [],
  ]; // 4 filas: símbolos, magnitudes, tiempos, heading
  List<double> primeraFilaMatrizOrdenada = [];

  // --- VARIABLES AÑADIDAS PARA COMPATIBILIDAD CON LA UI ---
  List<double> accMagnitudeListFiltered = [];
  List<double> accMagnitudeListFiltered2ndOrder = [];
  List<double> accMagnitudeListFiltered4thOrder = [];

  // Listas de resultados inicializadas como vacías y crecibles
  List<double> unionCrucesPicosVallesListFiltradoTotal = [];
  List<List<double>> matrizsignalfiltertotal = [];
  List<List<double>> matrizSecuenciasrevisar = [];
  List<double> unionFiltradorecortadoTotal = [];
  List<double> unionFiltradorecortadoTotal2 = [];
  List<int> pasosPorVentana = [];
  List<double> tiempoDePasosList = [];
  List<double> longitudDePasosList = [];
  List<List<double>> matrizordenadatotal = List.generate(5, (_) => []);
  List<double> tiemposRestados = [];

  // Datos de salida finales (incluye 4 filas: 3 originales + 1 para heading filtrado)
  List<List<double>> matrizDatosRecientes = List.generate(
    4,
    (_) => List.filled(4, 0.0),
  );
  List<List<double>> matrizPasos = List.generate(
    3,
    (i) => List.filled(20, 0.0),
  );

  /// Añade una nueva lectura de acelerómetro y giroscopio, la filtra y dispara el procesamiento por ventanas.
  void addSensorData(double magnitude, double gyroMagnitude, double heading) {
    // Paso 1: Filtrar los datos crudos en tiempo real
    final accFiltered = _accFilter.filter(magnitude);
    final gyroFiltered = _gyroFilter.filter(gyroMagnitude);
    final accFiltered2nd = _accFilter2ndOrder.filter(magnitude);
    final accFiltered4th = _accFilter4thOrder.filter(magnitude);

    // Paso 2: Crear un objeto `SensorReading` y añadirlo al historial principal
    readings.add(
      SensorReading(
        accMagnitude: magnitude,
        gyroMagnitude: gyroMagnitude,
        heading: heading,
        accFiltered: accFiltered,
        gyroFiltered: gyroFiltered,
        accFiltered2ndOrder: accFiltered2nd,
        accFiltered4thOrder: accFiltered4th,
      ),
    );

    // --- Poblar las listas adicionales para la UI ---
    accMagnitudeListFiltered.add(accFiltered);
    accMagnitudeListFiltered2ndOrder.add(accFiltered2nd);
    accMagnitudeListFiltered4thOrder.add(accFiltered4th);

    // Paso 3: Comprobar si hay suficientes datos para procesar una nueva ventana
    if (readings.length >= indiceInicio + ventanaTiempo) {
      _processPipelineForWindow(indiceInicio, indiceInicio + ventanaTiempo);
      indiceInicio +=
          ventanaTiempo; // Avanzar el índice para la próxima ventana
    }
  }

  /// Ejecuta toda la secuencia de análisis para una ventana de datos específica.
  void _processPipelineForWindow(int inicio, int fin) {
    if (inicio < desfase) {
      print(
        "Esperando más datos para procesar la primera ventana con desfase...",
      );
      return;
    }

    // Validación adicional para evitar range errors
    if (fin > readings.length ||
        inicio >= readings.length ||
        inicio < 0 ||
        fin <= inicio) {
      print(
        "Parámetros de ventana inválidos: inicio=$inicio, fin=$fin, readings.length=${readings.length}",
      );
      return;
    }

    if (inicio - desfase < 0 || fin - desfase > readings.length) {
      print(
        "Desfase inválido: inicio-desfase=${inicio - desfase}, fin-desfase=${fin - desfase}",
      );
      return;
    }

    // --- Preparación de las ventanas de datos ---
    final ventanaActual = readings.sublist(inicio, fin);
    final ventanaDesfasada = readings.sublist(inicio - desfase, fin - desfase);

    final accDesfasada = ventanaDesfasada.map((r) => r.accMagnitude).toList();
    final gyroDesfasada = ventanaDesfasada.map((r) => r.gyroMagnitude).toList();
    final accFiltrada = ventanaActual.map((r) => r.accFiltered).toList();
    final gyroFiltrada = ventanaActual.map((r) => r.gyroFiltered).toList();
    final headingWindow = ventanaActual.map((r) => r.heading).toList();

    // --- Poblar las listas reincorporadas ---
    accMagnitudeListDesfasada.addAll(accDesfasada);
    gyroMagnitudeListDesfasada.addAll(gyroDesfasada);
    historialFiltrado.addAll(accFiltrada);
    ventanaGyroXYZFiltradaList.addAll(gyroFiltrada);
    matrizsignalfiltertotal.add(accFiltrada);

    // --- Etapa 1: Cruces por cero ---
    final crucesPorCeroListFiltrado = AnalizadorDeSenales.crucesPorCero(
      accFiltrada,
    );

    // --- Etapa 2: Detección de picos ---
    final picosListFiltrado = AnalizadorDeSenales.deteccionPicos(
      accFiltrada,
      umbralPico,
    );
    final picosGyroFiltrado = AnalizadorDeSenales.deteccionPicos(
      gyroFiltrada,
      umbralGyroPico,
    );

    // --- Etapa 3: Detección de valles ---
    final vallesListFiltrado = AnalizadorDeSenales.deteccionValles(
      accFiltrada,
      umbralValle,
    );

    // --- Etapa 4: Unión de eventos ---
    final unionCrucesPicosVallesListFiltrado =
        AnalizadorDeSenales.unionCrucesPicosValles(
          crucesPorCeroListFiltrado,
          picosListFiltrado,
          vallesListFiltrado,
        );
    unionCrucesPicosVallesListFiltradoTotal.addAll(
      unionCrucesPicosVallesListFiltrado,
    );

    // --- Etapa 5: Procesamiento de matrices con heading integrado usando fusion_y_acortamiento_datos ---
    final indicesGyro = List.generate(
      picosGyroFiltrado.length,
      (i) => i.toDouble(),
    );
    final (simbolos, tiempos, magnitudes) = _acortaFusionaDatos
        .filtrarSimbolosCero(picosGyroFiltrado, gyroFiltrada, indicesGyro);
    final matrizGyro = [simbolos, tiempos, magnitudes];

    // Usar el nuevo método integrado que maneja heading directamente
    matrizordenada = _acortaFusionaDatos.matrizAcortadaConHeading(
      unionCrucesPicosVallesListFiltrado,
      accFiltrada,
      headingWindow,
    );

    primeraFilaMatrizOrdenada.addAll(matrizordenada[0]);

    // --- Etapa 6: Conteo de pasos ---
    conteoPasos.procesar(
      matrizordenada, // Matriz de 4 filas con heading integrado
      matrizDatosRecientes,
      matrizPasos,
      matrizSecuenciasrevisar,
      unionFiltradorecortadoTotal,
      unionFiltradorecortadoTotal2,
      ventanaTiempo,
      matrizGyro,
      tiemposRestados,
    );

    final pasosEnEstaVentana = matrizPasos[0][1].toInt();
    pasosPorVentana.add(pasosEnEstaVentana);

    // Validación antes de acceder a los arrays de pasos
    for (int i = 0; i < pasosEnEstaVentana; i++) {
      if (i < matrizPasos[1].length && i < matrizPasos[2].length) {
        tiempoDePasosList.add(matrizPasos[1][i]);
        longitudDePasosList.add(matrizPasos[2][i]);
      }
    }
    matrizPasos[0][1] = 0; // Resetear contador para la próxima ventana

    // --- Etapa 7: Finalización y consolidación de resultados ---
    // Primeras 3 filas: símbolos, magnitudes, tiempos de eventos
    for (int i = 0; i < 3; i++) {
      if (i < matrizordenada.length && i < matrizordenadatotal.length) {
        matrizordenadatotal[i].addAll(matrizordenada[i]);
      }
    }
    // Índice 3: tiempos de pasos (mantener estructura original)
    if (matrizordenadatotal.length > 3) {
      matrizordenadatotal[3] = List.from(tiempoDePasosList);
    }
    // Índice 4: datos de gyro (mantener estructura original)
    if (matrizordenadatotal.length > 4 && matrizGyro.length > 2) {
      matrizordenadatotal[4].addAll(matrizGyro[2]);
    }

    // TODO: Considerar expandir matrizordenadatotal para incluir heading en índice 5
    // si se necesita acceso global a los datos de heading procesados
  }

  /// Devuelve un mapa con el estado actual del procesador.
  Map<String, dynamic> getProcessorStatus() {
    return {
      'totalReadings': readings.length,
      'processedWindows': (indiceInicio / ventanaTiempo).floor(),
      'totalSteps': matrizPasos[0][2].toInt(),
      'stepsPerWindow': pasosPorVentana,
      'thresholds': {
        'umbralPico': umbralPico,
        'umbralValle': umbralValle,
        'umbralGyroPico': umbralGyroPico,
      },
    };
  }
}
