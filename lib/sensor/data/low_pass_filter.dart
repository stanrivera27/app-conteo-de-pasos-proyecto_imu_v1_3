import 'dart:math';

/// Filtro Butterworth público de 2do orden
/// (Antes llamado _StreamingFilterBase)
class StreamingFilter2ndOrder {
  double _x1 = 0.0, _x2 = 0.0;
  double _y1 = 0.0, _y2 = 0.0;
  
  final double a0, a1, a2, b1, b2;
  
  StreamingFilter2ndOrder({required double cutoffHz, required double fs}) :
    a0 = _calculateA0(cutoffHz, fs),
    a1 = _calculateA1(cutoffHz, fs),
    a2 = _calculateA2(cutoffHz, fs),
    b1 = _calculateB1(cutoffHz, fs),
    b2 = _calculateB2(cutoffHz, fs);
  
  double filter(double input) {
    double output = a0 * input + a1 * _x1 + a2 * _x2 - b1 * _y1 - b2 * _y2;
    
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    
    return output;
  }
  
  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0.0;
  }
  
  static double _calculateA0(double fc, double fs) {
    double w = 2 * pi * fc / fs;
    double cosw = cos(w);
    double sinw = sin(w);
    double alpha = sinw / (2 * sqrt(2));
    return (1 - cosw) / (2 * (1 + alpha));
  }
  
  static double _calculateA1(double fc, double fs) {
    double w = 2 * pi * fc / fs;
    double cosw = cos(w);
    double sinw = sin(w);
    double alpha = sinw / (2 * sqrt(2));
    return (1 - cosw) / (1 + alpha);
  }
  
  static double _calculateA2(double fc, double fs) {
    return _calculateA0(fc, fs);
  }
  
  static double _calculateB1(double fc, double fs) {
    double w = 2 * pi * fc / fs;
    double cosw = cos(w);
    double sinw = sin(w);
    double alpha = sinw / (2 * sqrt(2));
    return (-2 * cosw) / (1 + alpha);
  }
  
  static double _calculateB2(double fc, double fs) {
    double w = 2 * pi * fc / fs;
    double sinw = sin(w);
    double alpha = sinw / (2 * sqrt(2));
    return (1 - alpha) / (1 + alpha);
  }
}

/// Filtro público de 4to orden
/// (Antes llamado _StreamingFilter4thOrder)
class StreamingFilter4thOrder {
  late StreamingFilter2ndOrder _stage1;
  late StreamingFilter2ndOrder _stage2;
  
  StreamingFilter4thOrder({required double cutoffHz, required double fs}) {
    // Se usan las instancias de la clase pública recién renombrada
    _stage1 = StreamingFilter2ndOrder(cutoffHz: cutoffHz, fs: fs);
    _stage2 = StreamingFilter2ndOrder(cutoffHz: cutoffHz, fs: fs);
  }
  
  double filter(double input) {
    double intermediate = _stage1.filter(input);
    return _stage2.filter(intermediate);
  }
  
  void reset() {
    _stage1.reset();
    _stage2.reset();
  }
}

/// Filtro IIR pasa bajas en tiempo real con máximo suavizado
/// Combina filtro de 4to orden + promedio móvil exponencial
class StreamingFilter {
  late StreamingFilter4thOrder _mainFilter;
  double _emaOutput = 0.0;
  bool _initialized = false;
  final double _alpha;
  
  StreamingFilter({
    required double cutoffHz, 
    required double fs,
    double smoothingFactor = 0.1  // 0.1 = muy suave, 0.3 = menos suave
  }) : _alpha = smoothingFactor {
    // Se usa la instancia de la clase pública recién renombrada
    _mainFilter = StreamingFilter4thOrder(cutoffHz: cutoffHz, fs: fs);
  }
  
  /// Filtra una muestra individual con máximo suavizado
  double filter(double input) {
    // Primer paso: filtro de 4to orden
    double filtered = _mainFilter.filter(input);
    
    // Segundo paso: suavizado exponencial adicional
    if (!_initialized) {
      _emaOutput = filtered;
      _initialized = true;
    } else {
      _emaOutput = _alpha * filtered + (1 - _alpha) * _emaOutput;
    }
    
    return _emaOutput;
  }
  
  /// Resetea el estado del filtro
  void reset() {
    _mainFilter.reset();
    _emaOutput = 0.0;
    _initialized = false;
  }
}