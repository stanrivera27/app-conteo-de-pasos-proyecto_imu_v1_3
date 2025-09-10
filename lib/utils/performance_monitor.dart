import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  static PerformanceMonitor get instance => _instance ??= PerformanceMonitor._();
  
  PerformanceMonitor._();

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  
  // Métricas de rendimiento
  final Map<String, List<Duration>> _eventDurations = {};
  final Map<String, int> _eventCounts = {};
  final Queue<PerformanceEvent> _recentEvents = Queue();
  final Map<String, DateTime> _startTimes = {};
  
  // Métricas de memoria y CPU (simuladas)
  final List<double> _memoryUsageHistory = [];
  final List<double> _cpuUsageHistory = [];
  final List<int> _frameRateHistory = [];
  
  // Configuración
  static const int _maxHistorySize = 1000;
  static const int _maxRecentEvents = 100;
  static const Duration _monitoringInterval = Duration(seconds: 1);

  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(_monitoringInterval, _collectMetrics);
    
    if (kDebugMode) {
      print('PerformanceMonitor: Started monitoring');
    }
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    if (kDebugMode) {
      print('PerformanceMonitor: Stopped monitoring');
    }
  }

  void _collectMetrics(Timer timer) {
    try {
      // Simular métricas de memoria (en MB)
      final memoryUsage = _simulateMemoryUsage();
      _memoryUsageHistory.add(memoryUsage);
      
      // Simular métricas de CPU (porcentaje)
      final cpuUsage = _simulateCpuUsage();
      _cpuUsageHistory.add(cpuUsage);
      
      // Simular frame rate (FPS)
      final frameRate = _simulateFrameRate();
      _frameRateHistory.add(frameRate);
      
      // Limpiar historial si es demasiado grande
      _cleanupHistory();
      
    } catch (e) {
      if (kDebugMode) {
        print('PerformanceMonitor: Error collecting metrics: $e');
      }
    }
  }

  double _simulateMemoryUsage() {
    // Simula uso de memoria entre 50-200 MB con variaciones realistas
    final base = 100.0;
    final variation = 50.0;
    final randomFactor = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    return base + (variation * randomFactor);
  }

  double _simulateCpuUsage() {
    // Simula uso de CPU entre 10-80% con picos ocasionales
    final events = _recentEvents.length;
    final base = 20.0 + (events * 2.0).clamp(0.0, 40.0);
    final randomFactor = (DateTime.now().millisecondsSinceEpoch % 500) / 500.0;
    return (base + (20.0 * randomFactor)).clamp(5.0, 85.0);
  }

  int _simulateFrameRate() {
    // Simula frame rate entre 30-60 FPS basado en carga del sistema
    final cpuUsage = _cpuUsageHistory.isNotEmpty ? _cpuUsageHistory.last : 20.0;
    final baseFps = 60;
    final reduction = (cpuUsage / 100.0) * 30.0;
    return (baseFps - reduction).round().clamp(15, 60);
  }

  void _cleanupHistory() {
    if (_memoryUsageHistory.length > _maxHistorySize) {
      _memoryUsageHistory.removeAt(0);
    }
    if (_cpuUsageHistory.length > _maxHistorySize) {
      _cpuUsageHistory.removeAt(0);
    }
    if (_frameRateHistory.length > _maxHistorySize) {
      _frameRateHistory.removeAt(0);
    }
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeFirst();
    }
  }

  // API de eventos
  void recordEvent(String eventName, [Map<String, dynamic>? metadata]) {
    final now = DateTime.now();
    
    _eventCounts[eventName] = (_eventCounts[eventName] ?? 0) + 1;
    
    final event = PerformanceEvent(
      name: eventName,
      timestamp: now,
      metadata: metadata ?? {},
    );
    
    _recentEvents.add(event);
    
    if (kDebugMode && _isMonitoring) {
      print('PerformanceMonitor: Event recorded - $eventName');
    }
  }

  void startEvent(String eventName) {
    _startTimes[eventName] = DateTime.now();
  }

  void endEvent(String eventName) {
    final startTime = _startTimes.remove(eventName);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      
      _eventDurations.putIfAbsent(eventName, () => []).add(duration);
      
      recordEvent('${eventName}_completed', {
        'duration_ms': duration.inMilliseconds,
      });
      
      if (kDebugMode) {
        print('PerformanceMonitor: ${eventName} took ${duration.inMilliseconds}ms');
      }
    }
  }

  void recordDuration(String eventName, Duration duration) {
    _eventDurations.putIfAbsent(eventName, () => []).add(duration);
    recordEvent(eventName, {'duration_ms': duration.inMilliseconds});
  }

  void recordUIUpdate() {
    recordEvent('ui_update');
  }

  void recordSensorReading(String sensorType, double value) {
    recordEvent('sensor_reading', {
      'type': sensorType,
      'value': value,
    });
  }

  void recordPathCalculation(int pathLength, Duration calculationTime) {
    recordEvent('path_calculation', {
      'path_length': pathLength,
      'calculation_time_ms': calculationTime.inMilliseconds,
    });
  }

  // API de métricas
  PerformanceMetrics getMetrics() {
    return PerformanceMetrics(
      // Métricas de eventos
      totalEvents: _recentEvents.length,
      eventCounts: Map<String, int>.from(_eventCounts),
      
      // Métricas de rendimiento del sistema
      currentMemoryUsage: _memoryUsageHistory.isNotEmpty ? _memoryUsageHistory.last : 0.0,
      averageMemoryUsage: _calculateAverage(_memoryUsageHistory),
      peakMemoryUsage: _memoryUsageHistory.isNotEmpty ? _memoryUsageHistory.reduce((a, b) => a > b ? a : b) : 0.0,
      
      currentCpuUsage: _cpuUsageHistory.isNotEmpty ? _cpuUsageHistory.last : 0.0,
      averageCpuUsage: _calculateAverage(_cpuUsageHistory),
      peakCpuUsage: _cpuUsageHistory.isNotEmpty ? _cpuUsageHistory.reduce((a, b) => a > b ? a : b) : 0.0,
      
      currentFrameRate: _frameRateHistory.isNotEmpty ? _frameRateHistory.last : 0,
      averageFrameRate: _calculateAverageInt(_frameRateHistory),
      minFrameRate: _frameRateHistory.isNotEmpty ? _frameRateHistory.reduce((a, b) => a < b ? a : b) : 0,
      
      // Métricas de eventos con duración
      eventDurations: _eventDurations.map((key, value) => MapEntry(
        key,
        EventDurationMetrics(
          count: value.length,
          totalDuration: value.fold(Duration.zero, (sum, duration) => sum + duration),
          averageDuration: _calculateAverageDuration(value),
          minDuration: value.isEmpty ? Duration.zero : value.reduce((a, b) => a < b ? a : b),
          maxDuration: value.isEmpty ? Duration.zero : value.reduce((a, b) => a > b ? a : b),
        ),
      )),
      
      // Eventos recientes
      recentEvents: List<PerformanceEvent>.from(_recentEvents),
      
      // Estado del monitor
      isMonitoring: _isMonitoring,
      monitoringDuration: _isMonitoring && _monitoringTimer != null 
          ? DateTime.now().difference(_getMonitoringStartTime())
          : Duration.zero,
    );
  }

  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateAverageInt(List<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Duration _calculateAverageDuration(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    final totalMs = durations.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  DateTime _getMonitoringStartTime() {
    // Simplificación: usar el timestamp del primer evento reciente como referencia
    return _recentEvents.isNotEmpty 
        ? _recentEvents.first.timestamp
        : DateTime.now();
  }

  // Utilidades de diagnóstico
  String generateReport() {
    final metrics = getMetrics();
    final buffer = StringBuffer();
    
    buffer.writeln('=== Performance Report ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Monitoring: ${metrics.isMonitoring ? "Active" : "Inactive"}');
    buffer.writeln('');
    
    buffer.writeln('System Metrics:');
    buffer.writeln('  Memory: ${metrics.currentMemoryUsage.toStringAsFixed(1)} MB (avg: ${metrics.averageMemoryUsage.toStringAsFixed(1)} MB)');
    buffer.writeln('  CPU: ${metrics.currentCpuUsage.toStringAsFixed(1)}% (avg: ${metrics.averageCpuUsage.toStringAsFixed(1)}%)');
    buffer.writeln('  Frame Rate: ${metrics.currentFrameRate} FPS (avg: ${metrics.averageFrameRate.toStringAsFixed(1)} FPS)');
    buffer.writeln('');
    
    buffer.writeln('Event Statistics:');
    buffer.writeln('  Total Events: ${metrics.totalEvents}');
    
    final sortedEvents = metrics.eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedEvents.take(10)) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    
    if (metrics.eventDurations.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Event Durations:');
      
      final sortedDurations = metrics.eventDurations.entries.toList()
        ..sort((a, b) => b.value.averageDuration.compareTo(a.value.averageDuration));
      
      for (final entry in sortedDurations.take(5)) {
        final dur = entry.value;
        buffer.writeln('  ${entry.key}: avg ${dur.averageDuration.inMilliseconds}ms, '
            'max ${dur.maxDuration.inMilliseconds}ms (${dur.count} calls)');
      }
    }
    
    return buffer.toString();
  }

  void clearMetrics() {
    _eventDurations.clear();
    _eventCounts.clear();
    _recentEvents.clear();
    _startTimes.clear();
    _memoryUsageHistory.clear();
    _cpuUsageHistory.clear();
    _frameRateHistory.clear();
    
    if (kDebugMode) {
      print('PerformanceMonitor: Metrics cleared');
    }
  }

  void dispose() {
    stopMonitoring();
    clearMetrics();
    _instance = null;
  }
}

// Clases de datos para métricas
class PerformanceEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceEvent({
    required this.name,
    required this.timestamp,
    required this.metadata,
  });

  @override
  String toString() => '$name @ ${timestamp.toIso8601String()}';
}

class EventDurationMetrics {
  final int count;
  final Duration totalDuration;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;

  EventDurationMetrics({
    required this.count,
    required this.totalDuration,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
  });
}

class PerformanceMetrics {
  final int totalEvents;
  final Map<String, int> eventCounts;
  
  final double currentMemoryUsage;
  final double averageMemoryUsage;
  final double peakMemoryUsage;
  
  final double currentCpuUsage;
  final double averageCpuUsage;
  final double peakCpuUsage;
  
  final int currentFrameRate;
  final double averageFrameRate;
  final int minFrameRate;
  
  final Map<String, EventDurationMetrics> eventDurations;
  final List<PerformanceEvent> recentEvents;
  
  final bool isMonitoring;
  final Duration monitoringDuration;

  PerformanceMetrics({
    required this.totalEvents,
    required this.eventCounts,
    required this.currentMemoryUsage,
    required this.averageMemoryUsage,
    required this.peakMemoryUsage,
    required this.currentCpuUsage,
    required this.averageCpuUsage,
    required this.peakCpuUsage,
    required this.currentFrameRate,
    required this.averageFrameRate,
    required this.minFrameRate,
    required this.eventDurations,
    required this.recentEvents,
    required this.isMonitoring,
    required this.monitoringDuration,
  });
}