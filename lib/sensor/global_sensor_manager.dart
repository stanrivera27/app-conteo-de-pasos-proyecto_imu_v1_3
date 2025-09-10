import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:proyecto_imu_v1_3/sensor/sensor_manager.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import 'package:proyecto_imu_v1_3/utils/position_calculator.dart';
import 'package:proyecto_imu_v1_3/models/sensor_states.dart';

/// Global singleton for managing sensor state across multiple screens
/// Ensures sensor continuity when navigating between home and map screens
class GlobalSensorManager extends ChangeNotifier {
  static GlobalSensorManager? _instance;
  
  // Private constructor for singleton pattern
  GlobalSensorManager._();
  
  /// Get the singleton instance
  static GlobalSensorManager getInstance() {
    _instance ??= GlobalSensorManager._();
    return _instance!;
  }
  
  // Core sensor components
  SensorManager? _sensorManager;
  DataProcessor? _dataProcessor;
  
  // State management
  bool _isRunning = false;
  bool _isInitialized = false;
  final List<VoidCallback> _listeners = [];
  
  // Enhanced state tracking with throttling
  PositionState _positionState = PositionState.zero();
  SensorState _sensorState = SensorState.initial();
  List<List<double>>? _currentPath;
  
  // Stream controllers for real-time updates
  final StreamController<PositionState> _positionController = StreamController<PositionState>.broadcast();
  final StreamController<SensorState> _sensorController = StreamController<SensorState>.broadcast();
  final StreamController<bool> _runningStateController = StreamController<bool>.broadcast();
  
  // Throttling and performance control
  Timer? _updateTimer;
  Timer? _positionThrottleTimer;
  DateTime _lastPositionUpdate = DateTime.now();
  static const Duration _minPositionUpdateInterval = Duration(milliseconds: 200);
  static const Duration _minUIUpdateInterval = Duration(milliseconds: 100);
  
  // Performance tracking
  int _totalSteps = 0;
  double _totalDistance = 0.0;
  int _updateCount = 0;
  DateTime _lastPerformanceLog = DateTime.now();
  
  // Getters
  bool get isRunning => _isRunning;
  bool get isInitialized => _isInitialized;
  SensorManager? get sensorManager => _sensorManager;
  DataProcessor? get dataProcessor => _dataProcessor;
  PositionState get positionState => _positionState;
  SensorState get sensorState => _sensorState;
  List<List<double>>? get currentPath => _currentPath;
  int get totalSteps => _totalSteps;
  double get totalDistance => _totalDistance;
  
  // Stream getters for reactive UI updates
  Stream<PositionState> get positionStream => _positionController.stream;
  Stream<SensorState> get sensorStream => _sensorController.stream;
  Stream<bool> get runningStateStream => _runningStateController.stream;
  
  /// Initialize the global sensor manager
  void initialize() {
    if (_isInitialized) return;
    
    try {
      _dataProcessor = DataProcessor();
      _sensorManager = SensorManager(
        onUpdate: _onSensorDataUpdate,
        dataProcessor: _dataProcessor!,
      );
      
      // Start periodic updates for state management with throttling
      _updateTimer = Timer.periodic(_minUIUpdateInterval, (timer) {
        if (_isRunning) {
          _updateAllStatesThrottled();
        }
      });
      
      _isInitialized = true;
      debugPrint('GlobalSensorManager initialized successfully with throttling');
    } catch (e) {
      debugPrint('Failed to initialize GlobalSensorManager: $e');
      _isInitialized = false;
    }
  }
  
  /// Start sensor data collection
  void startSensors() {
    if (!_isInitialized) {
      initialize();
    }
    
    if (_sensorManager != null && !_isRunning) {
      _sensorManager!.toggleSensors();
      _isRunning = true;
      _runningStateController.add(true);
      _notifyListeners();
      debugPrint('Global sensors started');
    }
  }
  
  /// Stop sensor data collection
  void stopSensors() {
    if (_sensorManager != null && _isRunning) {
      _sensorManager!.toggleSensors();
      _isRunning = false;
      _runningStateController.add(false);
      _notifyListeners();
      debugPrint('Global sensors stopped');
    }
  }
  
  /// Toggle sensor state
  void toggleSensors() {
    if (_isRunning) {
      stopSensors();
    } else {
      startSensors();
    }
  }
  
  /// Add a listener for sensor data updates
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }
  
  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  /// Private method to handle sensor data updates with throttling
  void _onSensorDataUpdate() {
    _updateCount++;
    
    // Immediate lightweight updates
    _updateStepData();
    _notifyListeners();
    
    // Throttled position updates
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate) >= _minPositionUpdateInterval) {
      _updatePositionData();
      _lastPositionUpdate = now;
      
      // Cancel existing throttle timer
      _positionThrottleTimer?.cancel();
      
      // Set new throttle timer for position stream emission
      _positionThrottleTimer = Timer(_minPositionUpdateInterval, () {
        _emitPositionUpdate();
      });
    }
    
    // Performance logging (debug mode)
    if (kDebugMode && now.difference(_lastPerformanceLog).inSeconds >= 5) {
      _logPerformanceMetrics();
      _lastPerformanceLog = now;
    }
    
    notifyListeners(); // Notify ChangeNotifier listeners
  }
  
  /// Update all state objects with throttling
  void _updateAllStatesThrottled() {
    _updateSensorState();
    
    // Only emit to streams if enough time has passed
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate) >= _minPositionUpdateInterval) {
      _emitAllStreams();
    }
  }
  
  /// Emit position update to stream
  void _emitPositionUpdate() {
    if (!_positionController.isClosed) {
      _positionController.add(_positionState);
    }
  }
  
  /// Emit all stream updates
  void _emitAllStreams() {
    if (!_positionController.isClosed) {
      _positionController.add(_positionState);
    }
    if (!_sensorController.isClosed) {
      _sensorController.add(_sensorState);
    }
  }
  
  /// Log performance metrics for debugging
  void _logPerformanceMetrics() {
    debugPrint('GlobalSensorManager Performance:');
    debugPrint('  - Updates/sec: ${_updateCount / 5}');
    debugPrint('  - Total steps: $_totalSteps');
    debugPrint('  - Total distance: ${_totalDistance.toStringAsFixed(2)}m');
    debugPrint('  - Position accuracy: ${_positionState.accuracy.toStringAsFixed(2)}');
    debugPrint('  - Sensor frequency: ${_sensorManager?.frequency.toStringAsFixed(1)}Hz');
    _updateCount = 0;
  }
  
  /// Update sensor state with current metrics
  void _updateSensorState() {
    if (_sensorManager == null) return;
    
    try {
      final distances = _dataProcessor?.longitudDePasosList ?? [];
      final angles = _dataProcessor?.conteoPasos.averageAzimuthPerStep ?? [];
      
      _sensorState = SensorState(
        isRunning: _isRunning,
        frequency: _sensorManager!.frequency,
        stepCount: _totalSteps,
        totalDistance: _totalDistance,
        distances: List.from(distances),
        angles: List.from(angles),
        lastUpdate: DateTime.now(),
        healthStatus: getSensorHealthStatus(),
      );
    } catch (e) {
      debugPrint('Error updating sensor state: $e');
    }
  }
  
  /// Update position data using PositionCalculator with validation
  void _updatePositionData() {
    if (_dataProcessor == null) return;
    
    try {
      final distances = _dataProcessor!.longitudDePasosList;
      final angles = _dataProcessor!.conteoPasos.averageAzimuthPerStep;
      
      if (distances.isNotEmpty && angles.isNotEmpty) {
        // Ensure both lists have the same length
        final minLength = distances.length < angles.length ? distances.length : angles.length;
        final validDistances = distances.take(minLength).toList();
        final validAngles = angles.take(minLength).toList();
        
        // Only update if we have new data
        if (validDistances.isNotEmpty && validAngles.isNotEmpty) {
          // Calculate path using PositionCalculator
          final dydUnidas = [validDistances, validAngles];
          _currentPath = PositionCalculator.calcularRecorrido(dydUnidas);
          
          if (_currentPath != null && _currentPath!.isNotEmpty) {
            final positionResult = PositionCalculator.obtenerPosicionFinal(_currentPath!);
            final currentHeading = _sensorManager?.heading ?? 0.0;
            
            // Create new position state with improved accuracy calculation
            final newPosition = PositionState.fromCalculator(positionResult, currentHeading);
            
            // Only update if position has significantly changed (reduce noise)
            if (_shouldUpdatePosition(newPosition)) {
              _positionState = newPosition;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating position data: $e');
    }
  }
  
  /// Determine if position should be updated (noise reduction)
  bool _shouldUpdatePosition(PositionState newPosition) {
    const double minDistanceThreshold = 0.05; // 5cm minimum movement
    
    if (_positionState.x == 0.0 && _positionState.y == 0.0) {
      return true; // First position update
    }
    
    final distance = sqrt(
      pow(newPosition.x - _positionState.x, 2) + 
      pow(newPosition.y - _positionState.y, 2)
    );
    
    return distance >= minDistanceThreshold || 
           (newPosition.accuracy > _positionState.accuracy + 0.1);
  }
  
  /// Update step and distance counters
  void _updateStepData() {
    if (_dataProcessor == null) return;
    
    try {
      // Get total steps from data processor
      final newStepCount = _dataProcessor!.pasosPorVentana.fold<int>(0, (sum, steps) => sum + steps);
      _totalSteps = newStepCount;
      
      // Calculate total distance
      _totalDistance = PositionCalculator.calcularDistanciaTotal(_dataProcessor!.longitudDePasosList);
    } catch (e) {
      debugPrint('Error updating step data: $e');
    }
  }
  
  /// Notify all listeners of data changes
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error notifying listener: $e');
      }
    }
  }
  
  /// Get current sensor performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    if (_sensorManager == null) {
      return {
        'frequency': 0.0,
        'isRunning': false,
        'totalSteps': 0,
        'totalDistance': 0.0,
      };
    }
    
    return {
      'frequency': _sensorManager!.frequency,
      'isRunning': _isRunning,
      'totalSteps': _totalSteps,
      'totalDistance': _totalDistance,
      'sampleCount': _sensorManager!.sampleCount,
    };
  }
  
  /// Get sensor health status
  String getSensorHealthStatus() {
    if (!_isRunning) return 'Stopped';
    if (_sensorManager == null) return 'Not Initialized';
    
    final frequency = _sensorManager!.frequency;
    if (frequency < 50) return 'Poor';
    if (frequency < 80) return 'Good';
    return 'Excellent';
  }
  
  /// Reset all sensor data and position tracking
  void resetData() {
    _positionState = PositionState.zero();
    _sensorState = SensorState.initial();
    _currentPath = null;
    _totalSteps = 0;
    _totalDistance = 0.0;
    
    // Reset data processor if available
    if (_dataProcessor != null) {
      _dataProcessor!.accMagnitudeListDesfasada.clear();
      _dataProcessor!.historialFiltrado.clear();
      _dataProcessor!.indiceInicio = 0;
      _dataProcessor!.unionCrucesPicosVallesListFiltradoTotal.clear();
      _dataProcessor!.matrizordenada.clear();
      _dataProcessor!.matrizSecuenciasrevisar.clear();
      _dataProcessor!.unionFiltradorecortadoTotal.clear();
      _dataProcessor!.unionFiltradorecortadoTotal2.clear();
      _dataProcessor!.pasosPorVentana.clear();
      _dataProcessor!.tiempoDePasosList.clear();
      _dataProcessor!.longitudDePasosList.clear();
      _dataProcessor!.matrizsignalfiltertotal.clear();
      _dataProcessor!.tiemposRestados.clear();
      _dataProcessor!.primeraFilaMatrizOrdenada.clear();
      _dataProcessor!.readings.clear();
      _dataProcessor!.accMagnitudeListFiltered.clear();
      _dataProcessor!.accMagnitudeListFiltered2ndOrder.clear();
      _dataProcessor!.accMagnitudeListFiltered4thOrder.clear();
      
      // Reset matrices
      _dataProcessor!.matrizDatosRecientes = List.generate(4, (_) => List.filled(4, 0.0));
      _dataProcessor!.matrizPasos = List.generate(3, (i) => List.filled(20, 0.0));
      _dataProcessor!.matrizordenadatotal = [[], [], [], [], []];
      _dataProcessor!.gyroMagnitudeListDesfasada.clear();
      _dataProcessor!.ventanaGyroXYZFiltradaList.clear();
      
      // Reset azimuth data
      _dataProcessor!.conteoPasos.resetAzimuthData();
    }
    
    // Emit reset states to streams
    _positionController.add(_positionState);
    _sensorController.add(_sensorState);
    
    _notifyListeners();
    notifyListeners();
    debugPrint('Global sensor data reset');
  }
  
  /// Dispose of the global sensor manager
  @override
  void dispose() {
    _updateTimer?.cancel();
    _positionThrottleTimer?.cancel();
    _sensorManager?.dispose();
    _listeners.clear();
    
    // Close stream controllers
    _positionController.close();
    _sensorController.close();
    _runningStateController.close();
    
    _isInitialized = false;
    _isRunning = false;
    super.dispose();
    debugPrint('GlobalSensorManager disposed');
  }
  
  /// Get real-time position stream with throttling
  Stream<PositionState> get positionStreamThrottled {
    return _positionController.stream
        .where((position) => position.isValid)
        .distinct((prev, curr) => 
            (curr.x - prev.x).abs() < 0.01 && 
            (curr.y - prev.y).abs() < 0.01);
  }
  
  /// Get high-frequency position stream (for internal use)
  Stream<PositionState> get positionStreamHighFreq => _positionController.stream;
  
  /// Get current movement speed in m/s
  double get currentSpeed {
    if (_currentPath == null || _currentPath!.isEmpty || _currentPath![0].length < 2) {
      return 0.0;
    }
    
    try {
      final positions = _currentPath![0];
      final lastIndex = positions.length - 1;
      
      if (lastIndex < 1) return 0.0;
      
      final distance = (positions[lastIndex] - positions[lastIndex - 1]).abs();
      const timeInterval = 1.0; // Approximate 1 second between readings
      
      return distance / timeInterval;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Get position confidence based on recent data consistency
  double get positionConfidence {
    if (_sensorState.distances.length < 3) return 0.0;
    
    try {
      // Calculate variance in recent distance measurements
      final recentDistances = _sensorState.distances.take(5).toList();
      if (recentDistances.length < 2) return 0.0;
      
      final mean = recentDistances.reduce((a, b) => a + b) / recentDistances.length;
      final variance = recentDistances
          .map((d) => (d - mean) * (d - mean))
          .reduce((a, b) => a + b) / recentDistances.length;
      
      // Convert variance to confidence (lower variance = higher confidence)
      final confidence = 1.0 / (1.0 + variance * 10);
      return confidence.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Force disposal (for testing or complete reset)
  static void forceDispose() {
    _instance?.dispose();
    _instance = null;
  }
}