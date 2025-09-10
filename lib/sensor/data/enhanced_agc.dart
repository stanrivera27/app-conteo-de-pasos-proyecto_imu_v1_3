import 'dart:math';
import 'dart:collection';

/// Filtro Kalman simplificado para estimación de ruido
class SimpleKalmanFilter {
  double _estimate = 0.0;
  double _errorCovariance = 1.0;
  final double _processNoise;
  final double _measurementNoise;
  SimpleKalmanFilter({
    double processNoise = 0.01,
    double measurementNoise = 0.1,
  }) : _processNoise = processNoise,
       _measurementNoise = measurementNoise;
  double update(double measurement) {
    // Prediction
    _errorCovariance += _processNoise;
    // Update
    double kalmanGain =
        _errorCovariance / (_errorCovariance + _measurementNoise);
    _estimate += kalmanGain * (measurement - _estimate);
    _errorCovariance *= (1.0 - kalmanGain);
    return _estimate;
  }

  void reset() {
    _estimate = 0.0;
    _errorCovariance = 1.0;
  }
}

/// Filtro de mediana móvil para reducir spikes
class MedianFilter {
  final Queue<double> _buffer = Queue<double>();
  final int _windowSize;
  MedianFilter(this._windowSize);
  double filter(double input) {
    _buffer.add(input);
    if (_buffer.length > _windowSize) {
      _buffer.removeFirst();
    }

    // Validación para evitar range errors
    if (_buffer.isEmpty) {
      return input;
    }

    List<double> sorted = List.from(_buffer)..sort();
    int middle = sorted.length ~/ 2;

    // Validación adicional de límites
    if (sorted.isEmpty) {
      return input;
    }

    if (sorted.length % 2 == 0) {
      // Validar que middle-1 esté dentro de límites
      if (middle > 0 && middle < sorted.length) {
        return (sorted[middle - 1] + sorted[middle]) / 2.0;
      } else if (middle >= sorted.length && sorted.isNotEmpty) {
        return sorted.last;
      } else if (middle <= 0 && sorted.isNotEmpty) {
        return sorted.first;
      }
    } else {
      // Validar que middle esté dentro de límites
      if (middle >= 0 && middle < sorted.length) {
        return sorted[middle];
      }
    }

    // Valor por defecto si algo sale mal
    return input;
  }

  void reset() {
    _buffer.clear();
  }
}

/// Detector de outliers usando desviación estándar
class OutlierDetector {
  final Queue<double> _history = Queue<double>();
  final int _windowSize;
  final double _threshold;
  OutlierDetector({
    int windowSize = 20,
    double threshold = 2.5, // Desviaciones estándar
  }) : _windowSize = windowSize,
       _threshold = threshold;
  bool isOutlier(double value) {
    if (_history.length < _windowSize ~/ 2) {
      _history.add(value);
      return false;
    }

    // Validación para evitar división por cero y range errors
    if (_history.isEmpty) {
      _history.add(value);
      return false;
    }

    double mean = _history.reduce((a, b) => a + b) / _history.length;
    double variance =
        _history.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
        _history.length;
    double stdDev = sqrt(variance);

    // Validación adicional para evitar problemas con valores no finitos
    if (!stdDev.isFinite || stdDev <= 0) {
      _history.add(value);
      if (_history.length > _windowSize) {
        _history.removeFirst();
      }
      return false;
    }

    bool isOutlier = (value - mean).abs() > _threshold * stdDev;
    _history.add(value);
    if (_history.length > _windowSize) {
      _history.removeFirst();
    }
    return isOutlier;
  }

  void reset() {
    _history.clear();
  }
}

/// Control Automático de Ganancia de Ultra Bajo Ruido
class UltraLowNoiseAGC {
  final double _targetAmplitude;
  double _currentGain = 1.0;
  double _smoothedGain = 1.0;
  // Estimadores de ruido avanzados
  late final SimpleKalmanFilter _energyKalman;
  late final SimpleKalmanFilter _noiseKalman;
  late final MedianFilter _medianFilter;
  late final OutlierDetector _outlierDetector;
  // Parámetros de adaptación ultra suaves
  final double _attackRate;
  final double _releaseRate;
  final double _gainSmoothing;
  final double _energySmoothing;
  // Estado del filtro
  double _filteredEnergy = 1.0;
  double _noiseFloor = 0.001;
  double _peakEnergy = 1.0;
  final double _peakDecay;
  // Historial para análisis espectral básico
  final Queue<double> _recentSamples = Queue<double>();
  final int _analysisWindowSize = 50;
  // Métricas de calidad mejoradas
  double _snrEstimate = 20.0;
  double _stabilityMetric = 1.0;
  int _consecutiveStableFrames = 0;
  UltraLowNoiseAGC({
    double targetAmplitude = 1.0,
    double attackRate = 0.001, // Mucho más lento
    double releaseRate = 0.0005, // Mucho más lento
    double gainSmoothing = 0.95, // Suavizado agresivo
    double energySmoothing = 0.02,
    double peakDecay = 0.0001, // Decaimiento muy lento
  }) : _targetAmplitude = targetAmplitude,
       _attackRate = attackRate,
       _releaseRate = releaseRate,
       _gainSmoothing = gainSmoothing,
       _energySmoothing = energySmoothing,
       _peakDecay = peakDecay {
    _energyKalman = SimpleKalmanFilter(
      processNoise: 0.001,
      measurementNoise: 0.05,
    );
    _noiseKalman = SimpleKalmanFilter(
      processNoise: 0.0001,
      measurementNoise: 0.02,
    );
    _medianFilter = MedianFilter(11);
    _outlierDetector = OutlierDetector(
      windowSize: 25,
      threshold: 2.0, // Más conservador
    );
  }
  double process(double input) {
    // Validación de entrada para mayor robustez
    if (!input.isFinite) {
      return _recentSamples.isNotEmpty ? _recentSamples.last : 0.0;
    }
    // Paso 1: Detección y filtrado de outliers
    double cleanInput = input;
    if (_outlierDetector.isOutlier(input.abs())) {
      // Usar el último valor confiable en lugar del outlier
      cleanInput =
          _recentSamples.isNotEmpty ? _recentSamples.last : input * 0.1;
    }
    // Paso 2: Filtrado de mediana para reducir spikes
    double medianFiltered = _medianFilter.filter(cleanInput.abs());
    // Paso 3: Estimación Kalman de energía
    double kalmanEnergy = _energyKalman.update(medianFiltered);
    // Paso 4: Actualizar energía filtrada con suavizado extremo
    _filteredEnergy += _energySmoothing * (kalmanEnergy - _filteredEnergy);
    // Paso 5: Estimación adaptativa del piso de ruido
    _updateNoiseFloor(medianFiltered);
    // Paso 6: Análisis de estabilidad
    _updateStabilityMetrics();
    // Paso 7: Cálculo de ganancia con múltiples consideraciones
    double targetGain = _calculateSmartGain();
    // Paso 8: Suavizado ultra agresivo de la ganancia
    _updateGainWithStabilityConsideration(targetGain);
    // Paso 9: Mantener historial para análisis
    _maintainHistory(cleanInput);
    // Validar salida final
    double output = input * _smoothedGain;
    return output.isFinite ? output : input;
  }

  void _updateNoiseFloor(double energy) {
    // Validar entrada
    if (!energy.isFinite || energy < 0) return;
    // Usar Kalman para estimar el piso de ruido
    double noiseEstimate = _noiseKalman.update(energy);
    // Solo actualizar si es menor que el actual (ruido debe ser mínimo)
    if (noiseEstimate < _filteredEnergy * 0.3) {
      _noiseFloor = 0.99 * _noiseFloor + 0.01 * noiseEstimate;
    }
    // Límites conservadores con validación
    _noiseFloor = _noiseFloor.clamp(0.0001, 0.1);
    if (!_noiseFloor.isFinite) _noiseFloor = 0.001;
  }

  void _updateStabilityMetrics() {
    // Medir estabilidad basada en variaciones de ganancia
    double gainVariation = (_currentGain - _smoothedGain).abs();
    if (gainVariation < 0.01) {
      _consecutiveStableFrames++;
    } else {
      _consecutiveStableFrames = 0;
    }
    // Métrica de estabilidad (0-1, donde 1 es muy estable)
    _stabilityMetric = (_consecutiveStableFrames / 100.0).clamp(0.0, 1.0);
  }

  double _calculateSmartGain() {
    double effectiveEnergy = (_filteredEnergy - _noiseFloor).clamp(0.001, 10.0);
    double baseGain = _targetAmplitude / effectiveEnergy;
    // Factor de corrección basado en SNR
    double snrFactor = _calculateSNRFactor();
    // Factor de estabilidad - más estable = menos cambios
    double stabilityFactor = 0.5 + 0.5 * _stabilityMetric;
    // Combinar factores
    double smartGain = baseGain * snrFactor * stabilityFactor;
    // Límites dinámicos basados en condiciones
    double minGain = _noiseFloor > 0.01 ? 0.1 : 0.05;
    double maxGain = _snrEstimate > 15.0 ? 2.0 : 3.0;
    return smartGain.clamp(minGain, maxGain);
  }

  double _calculateSNRFactor() {
    if (_noiseFloor > 0 && _filteredEnergy.isFinite && _noiseFloor.isFinite) {
      double ratio = _filteredEnergy / _noiseFloor;
      if (ratio > 0) {
        _snrEstimate = 20 * log(ratio) / ln10;
      }
    }
    // Factor de corrección basado en SNR con límites robustos
    _snrEstimate = _snrEstimate.clamp(-10.0, 50.0); // Límites razonables
    if (_snrEstimate > 20.0) {
      return 1.0; // SNR excelente, ganancia normal
    } else if (_snrEstimate > 10.0) {
      return 0.8; // SNR bueno, reducir ganancia ligeramente
    } else {
      return 0.6; // SNR pobre, reducir ganancia más
    }
  }

  void _updateGainWithStabilityConsideration(double targetGain) {
    // Validar entrada
    if (!targetGain.isFinite || targetGain <= 0) return;
    // Tasa de cambio adaptativa basada en estabilidad
    double adaptiveAttackRate = _attackRate * (1.0 + _stabilityMetric);
    double adaptiveReleaseRate = _releaseRate * (1.0 + _stabilityMetric);
    // Actualizar ganancia actual con validación
    if (targetGain > _currentGain) {
      double newGain =
          _currentGain + adaptiveAttackRate * (targetGain - _currentGain);
      _currentGain = newGain.isFinite ? newGain : _currentGain;
    } else {
      double newGain =
          _currentGain + adaptiveReleaseRate * (targetGain - _currentGain);
      _currentGain = newGain.isFinite ? newGain : _currentGain;
    }
    // Suavizado ultra agresivo para la ganancia final con validación
    double newSmoothedGain =
        _smoothedGain + (1.0 - _gainSmoothing) * (_currentGain - _smoothedGain);
    _smoothedGain = newSmoothedGain.isFinite ? newSmoothedGain : _smoothedGain;
    // Asegurar límites finales de seguridad
    _currentGain = _currentGain.clamp(0.01, 10.0);
    _smoothedGain = _smoothedGain.clamp(0.01, 10.0);
  }

  void _maintainHistory(double sample) {
    _recentSamples.add(sample);
    if (_recentSamples.length > _analysisWindowSize) {
      _recentSamples.removeFirst();
    }
    // Actualizar pico con decaimiento muy lento
    if (sample.abs() > _peakEnergy) {
      _peakEnergy = sample.abs();
    } else {
      _peakEnergy = _peakEnergy * (1.0 - _peakDecay);
    }
  }

  void reset() {
    _currentGain = 1.0;
    _smoothedGain = 1.0;
    _filteredEnergy = 1.0;
    _noiseFloor = 0.001;
    _peakEnergy = 1.0;
    _snrEstimate = 20.0;
    _stabilityMetric = 1.0;
    _consecutiveStableFrames = 0;
    _energyKalman.reset();
    _noiseKalman.reset();
    _medianFilter.reset();
    _outlierDetector.reset();
    _recentSamples.clear();
  }

  // Getters mejorados
  double get currentGain => _smoothedGain;
  double get rawGain => _currentGain;
  double get currentEnergy => _filteredEnergy;
  double get peakEnergy => _peakEnergy;
  double get noiseFloor => _noiseFloor;
  double get snr => _snrEstimate;
  double get stability => _stabilityMetric;
  bool get isStable => _consecutiveStableFrames > 50;
  // Métricas adicionales para diagnóstico
  Map<String, dynamic> getDiagnostics() {
    return {
      'smoothedGain': _smoothedGain,
      'rawGain': _currentGain,
      'filteredEnergy': _filteredEnergy,
      'noiseFloor': _noiseFloor,
      'snr': _snrEstimate,
      'stability': _stabilityMetric,
      'consecutiveStableFrames': _consecutiveStableFrames,
      'isStable': isStable,
      'peakEnergy': _peakEnergy,
      'effectiveRange': (_peakEnergy - _noiseFloor),
    };
  }
}

/// Presets optimizados para ultra bajo ruido
class UltraLowNoisePresets {
  /// Preset para acelerómetro con mínimo ruido
  static UltraLowNoiseAGC forAccelerometer() {
    return UltraLowNoiseAGC(
      targetAmplitude: 1.1,
      attackRate: 0.0008, // Muy lento
      releaseRate: 0.0004, // Muy lento
      gainSmoothing: 0.98, // Suavizado extremo
      energySmoothing: 0.015, // Muy suave
      peakDecay: 0.00005, // Decaimiento muy lento
    );
  }

  /// Preset para giroscopio con mínimo ruido
  static UltraLowNoiseAGC forGyroscope() {
    return UltraLowNoiseAGC(
      targetAmplitude: 0.9,
      attackRate: 0.0006, // Muy lento
      releaseRate: 0.0003, // Muy lento
      gainSmoothing: 0.99, // Suavizado máximo
      energySmoothing: 0.01, // Extremadamente suave
      peakDecay: 0.00003, // Decaimiento extremadamente lento
    );
  }

  /// Preset para condiciones de mucho ruido
  static UltraLowNoiseAGC forNoisyEnvironment() {
    return UltraLowNoiseAGC(
      targetAmplitude:
          1.0, // Objetivo un poco más alto para una señal más "llena"
      attackRate: 0.5, // Ataque ~125x más rápido que el de acelerómetro
      releaseRate: 0.005, // Liberación ~125x más rápida
      gainSmoothing: 0.8, // Suavizado mucho menor para reacciones rápidas
      energySmoothing: 0.1, // Detección de energía más reactiva
      peakDecay: 0.01, // Casi sin decaimiento
    );
  }

  static UltraLowNoiseAGC forTransparentSignal() {
    return UltraLowNoiseAGC(
      targetAmplitude: 1.0,
      attackRate: 0.1, // Reacción extremadamente lenta, casi nula.
      releaseRate: 0.0001, // Reacción aún más lenta.
      gainSmoothing: 0.8, // Suavizado máximo para que la ganancia no cambie.
      // Los otros parámetros tienen menos impacto, pero se dejan en valores suaves.
      energySmoothing: 0.1,
      peakDecay: 0.00001,
    );
  }
}
