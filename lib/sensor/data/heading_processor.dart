/// Clase para el procesamiento de datos de heading/azimuth
class HeadingProcessor {
  static const int _patternSize = 5;
  static const int _requiredRows = 4;
  static const int _headingRowIndex = 3;
  static const int _timeRowIndex = 2;
  static const double _defaultHeadingValue = 0.0;
  static const double _discontinuityThresholdHigh = 270.0;
  static const double _discontinuityThresholdLow = 90.0;
  static const double _fullCircle = 360.0;

  final List<double> _averageAzimuthPerStep = [];
  final List<List<double>> _headingPatternsPerStep = [];

  List<double> get averageAzimuthPerStep =>
      List<double>.from(_averageAzimuthPerStep);

  List<List<double>> get headingPatternsPerStep =>
      _headingPatternsPerStep
          .map((pattern) => List<double>.from(pattern))
          .toList();

  void procesarAzimuthPaso(
    List<List<double>> matrizDatosAcortada,
    int i,
    double tiempo1,
    double tiempo2,
  ) {
    if (matrizDatosAcortada.length < _requiredRows ||
        matrizDatosAcortada[0].length <= i + _patternSize - 1 ||
        matrizDatosAcortada[_headingRowIndex].length !=
            matrizDatosAcortada[0].length ||
        tiempo1 >= tiempo2 ||
        i < 0) {
      _averageAzimuthPerStep.add(_defaultHeadingValue);
      _headingPatternsPerStep.add(
        List.filled(_patternSize, _defaultHeadingValue),
      );
      return;
    }

    try {
      final headingPattern = <double>[];
      final timePattern = <double>[];

      for (int j = 0; j < _patternSize; j++) {
        headingPattern.add(matrizDatosAcortada[_headingRowIndex][i + j]);
        timePattern.add(matrizDatosAcortada[_timeRowIndex][i + j]);
      }

      final averageAzimuth = promedioAzimuth(
        tiempo1,
        tiempo2,
        timePattern,
        headingPattern,
      );
      _averageAzimuthPerStep.add(averageAzimuth);
      _headingPatternsPerStep.add(List<double>.from(headingPattern));
    } catch (e) {
      _averageAzimuthPerStep.add(_defaultHeadingValue);
      _headingPatternsPerStep.add(
        List.filled(_patternSize, _defaultHeadingValue),
      );
    }
  }

  double promedioAzimuth(
    double startTime,
    double endTime,
    List<double> timeArray,
    List<double> azimuthArray,
  ) {
    if (timeArray.isEmpty ||
        azimuthArray.isEmpty ||
        timeArray.length != azimuthArray.length ||
        startTime >= endTime) {
      return _defaultHeadingValue;
    }

    final intervalData = <double>[];
    for (int i = 0; i < timeArray.length; i++) {
      // Validación adicional de límites para evitar range errors
      if (i >= timeArray.length || i >= azimuthArray.length) {
        break;
      }
      if (timeArray[i] >= startTime && timeArray[i] <= endTime) {
        intervalData.add(azimuthArray[i]);
      }
    }

    if (intervalData.isEmpty) {
      final tiempoMedio = (startTime + endTime) / 2;
      int indiceMinimo = 0;
      double diferenciaMinima = (timeArray[0] - tiempoMedio).abs();

      for (int i = 1; i < timeArray.length; i++) {
        // Validación adicional de límites
        if (i >= timeArray.length) {
          break;
        }
        final diferencia = (timeArray[i] - tiempoMedio).abs();
        if (diferencia < diferenciaMinima) {
          diferenciaMinima = diferencia;
          indiceMinimo = i;
        }
      }
      // Validar que indiceMinimo esté dentro de límites antes de acceder al array
      if (indiceMinimo >= 0 && indiceMinimo < azimuthArray.length) {
        return azimuthArray[indiceMinimo];
      } else {
        return _defaultHeadingValue;
      }
    }

    if (intervalData.length == 1) return intervalData.first;

    // Normalizar discontinuidad 359° → 0°
    int valoresArriba270 = 0;
    int valoresAbajo90 = 0;
    for (final azimuth in intervalData) {
      if (azimuth > _discontinuityThresholdHigh) valoresArriba270++;
      if (azimuth < _discontinuityThresholdLow) valoresAbajo90++;
    }

    final normalizedValues = List<double>.from(intervalData);
    if (valoresArriba270 > 0 && valoresAbajo90 > 0) {
      for (int i = 0; i < normalizedValues.length; i++) {
        // Validación adicional de límites
        if (i >= normalizedValues.length) {
          break;
        }
        if (normalizedValues[i] < _discontinuityThresholdLow) {
          normalizedValues[i] += _fullCircle;
        }
      }
    }

    // Promedio ponderado
    final n = normalizedValues.length;
    double sumaPonderada = 0.0;
    double sumaPesos = 0.0;

    for (int i = 0; i < n; i++) {
      // Validación adicional de límites
      if (i >= normalizedValues.length) {
        break;
      }
      final peso = (i + 1).toDouble();
      sumaPonderada += normalizedValues[i] * peso;
      sumaPesos += peso;
    }

    // Validar división por cero
    if (sumaPesos == 0) {
      return _defaultHeadingValue;
    }

    double promedio = sumaPonderada / sumaPesos;
    if (promedio >= _fullCircle) promedio -= _fullCircle;

    return promedio;
  }

  void resetAzimuthData() {
    _averageAzimuthPerStep.clear();
    _headingPatternsPerStep.clear();
  }
}
