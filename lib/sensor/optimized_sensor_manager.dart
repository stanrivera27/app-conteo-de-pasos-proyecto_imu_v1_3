import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'data/sensor_processor.dart';
import '../utils/performance_monitor.dart';

class OptimizedSensorManager {
  // Datos del sensor optimizados
  final DataProcessor dataProcessor;
  double accX = 0.0, accY = 0.0, accZ = 0.0;
  double accMagnitude = 0.0;
  double gyroX = 0.0, gyroY = 0.0, gyroZ = 0.0;
  double gyroMagnitude = 0.0;
  double? heading = 0.0;

  // Filtros Kalman optimizados
  double kalmanAccX = 0.0, kalmanAccY = 0.0, kalmanAccZ = 0.0;
  double kalmanGyroX = 0.0, kalmanGyroY = 0.0, kalmanGyroZ = 0.0;
  double kalmanAccMagnitude = 0.0;
  double kalmanGyroMagnitude = 0.0;
  
  double frequency = 0;
  bool isRunning = false;
  int sampleCount = 0;

  // Intervalos optimizados para mejor rendimiento
  final Duration sensorInterval = const Duration(microseconds: 8000); // 125 Hz
  StreamSubscription<AccelerometerEvent>? _accSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  late Timer _timer;

  // Callback optimizado
  final VoidCallback onUpdate;

  // Buffer circular para datos optimizados
  static const int _bufferSize = 50;
  final List<double> _accBuffer = [];
  final List<double> _gyroBuffer = [];
  int _bufferIndex = 0;

  OptimizedSensorManager({
    required this.onUpdate, 
    required this.dataProcessor
  }) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isRunning) {
        frequency = sampleCount.toDouble();
        sampleCount = 0;
        onUpdate();
      }
    });
  }

  void startSensors() {
    PerformanceMonitor.instance.recordEvent('sensors_start');
    
    // Iniciar brújula optimizada
    _compassSubscription = FlutterCompass.events?.listen((event) {
      double? newHeading = event.heading;
      if (newHeading != null) {
        heading = (newHeading + 360) % 360;
        _updateOptimizedData();
      }
    });

    // Giroscopio optimizado
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: sensorInterval,
    ).listen((event) {
      gyroX = event.x;
      gyroY = event.y;
      gyroZ = event.z;
      gyroMagnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      
      _updateGyroBuffer(gyroMagnitude);
      _updateOptimizedData();
    });

    // Acelerómetro optimizado
    _accSubscription = accelerometerEventStream(
      samplingPeriod: sensorInterval,
    ).listen((event) {
      accX = event.x;
      accY = event.y;
      accZ = event.z;
      accMagnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      ) - 9.8;

      _updateAccBuffer(accMagnitude);
      
      // Procesar datos con heading incluido
      dataProcessor.addSensorData(
        accMagnitude,
        gyroMagnitude,
        heading ?? 0.0,
      );

      sampleCount++;
      _updateOptimizedData();
    });

    isRunning = true;
  }

  void _updateAccBuffer(double value) {
    if (_accBuffer.length < _bufferSize) {
      _accBuffer.add(value);
    } else {
      _accBuffer[_bufferIndex % _bufferSize] = value;
    }
  }

  void _updateGyroBuffer(double value) {
    if (_gyroBuffer.length < _bufferSize) {
      _gyroBuffer.add(value);
    } else {
      _gyroBuffer[_bufferIndex % _bufferSize] = value;
    }
    _bufferIndex++;
  }

  void _updateOptimizedData() {
    // Aplicar filtros optimizados solo cuando sea necesario
    if (_accBuffer.isNotEmpty) {
      kalmanAccMagnitude = _applyKalmanFilter(_accBuffer.last);
    }
    if (_gyroBuffer.isNotEmpty) {
      kalmanGyroMagnitude = _applyKalmanFilter(_gyroBuffer.last);
    }
    
    onUpdate();
  }

  double _applyKalmanFilter(double measurement) {
    // Filtro Kalman simplificado para mejor rendimiento
    double estimate = 0.0;
    double errorEstimate = 1.0;
    
    const double processNoise = 0.01;
    const double measurementNoise = 0.1;
    
    // Predicción
    double errorPrediction = errorEstimate + processNoise;
    
    // Actualización
    double kalmanGain = errorPrediction / (errorPrediction + measurementNoise);
    estimate = estimate + kalmanGain * (measurement - estimate);
    errorEstimate = (1 - kalmanGain) * errorPrediction;
    
    return estimate;
  }

  void stopSensors() {
    PerformanceMonitor.instance.recordEvent('sensors_stop');
    
    _accSubscription?.cancel();
    _gyroSubscription?.cancel();
    _compassSubscription?.cancel();
    
    _accSubscription = null;
    _gyroSubscription = null;
    _compassSubscription = null;
    
    isRunning = false;
  }

  void toggleSensors() {
    if (isRunning) {
      stopSensors();
    } else {
      _resetDataProcessor();
      startSensors();
    }
    onUpdate();
  }

  void _resetDataProcessor() {
    // Limpiar todos los buffers de manera optimizada
    dataProcessor.accMagnitudeListDesfasada.clear();
    dataProcessor.historialFiltrado.clear();
    dataProcessor.indiceInicio = 0;
    dataProcessor.unionCrucesPicosVallesListFiltradoTotal.clear();
    dataProcessor.matrizordenada.clear();
    dataProcessor.matrizSecuenciasrevisar.clear();
    dataProcessor.unionFiltradorecortadoTotal.clear();
    dataProcessor.unionFiltradorecortadoTotal2.clear();
    dataProcessor.pasosPorVentana.clear();
    dataProcessor.tiempoDePasosList.clear();
    dataProcessor.longitudDePasosList.clear();
    dataProcessor.matrizsignalfiltertotal.clear();
    dataProcessor.tiemposRestados.clear();
    dataProcessor.primeraFilaMatrizOrdenada.clear();

    // Limpiar historial completo
    dataProcessor.readings.clear();
    dataProcessor.accMagnitudeListFiltered.clear();
    dataProcessor.accMagnitudeListFiltered2ndOrder.clear();
    dataProcessor.accMagnitudeListFiltered4thOrder.clear();

    // Reinicializar matrices optimizadas
    dataProcessor.matrizDatosRecientes = List.generate(
      4, (_) => List.filled(4, 0.0),
    );
    dataProcessor.matrizPasos = List.generate(
      3, (i) => List.filled(20, 0.0)
    );

    dataProcessor.matrizordenadatotal = [[], [], [], [], []];
    dataProcessor.gyroMagnitudeListDesfasada.clear();
    dataProcessor.ventanaGyroXYZFiltradaList.clear();

    // Reset azimuth data
    dataProcessor.conteoPasos.resetAzimuthData();

    // Limpiar buffers locales
    _accBuffer.clear();
    _gyroBuffer.clear();
    _bufferIndex = 0;
  }

  // Métodos adicionales para acceso optimizado a datos
  double get smoothedAccMagnitude => kalmanAccMagnitude;
  double get smoothedGyroMagnitude => kalmanGyroMagnitude;
  
  bool get hasStableReading => _accBuffer.length >= _bufferSize ~/ 2;
  
  double get averageAccMagnitude {
    if (_accBuffer.isEmpty) return 0.0;
    return _accBuffer.reduce((a, b) => a + b) / _accBuffer.length;
  }

  double get averageGyroMagnitude {
    if (_gyroBuffer.isEmpty) return 0.0;
    return _gyroBuffer.reduce((a, b) => a + b) / _gyroBuffer.length;
  }

  // Métodos adicionales requeridos por map_screen
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'frequency': frequency,
      'sampleCount': sampleCount,
      'bufferSize': _accBuffer.length,
      'isRunning': isRunning,
      'kalmanAccMagnitude': kalmanAccMagnitude,
      'kalmanGyroMagnitude': kalmanGyroMagnitude,
    };
  }

  String getSensorHealthStatus() {
    if (!isRunning) return 'Stopped';
    if (frequency < 50) return 'Poor';
    if (frequency < 80) return 'Good';
    return 'Excellent';
  }

  void dispose() {
    _timer.cancel();
    stopSensors();
  }
}