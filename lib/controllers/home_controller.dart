import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:proyecto_imu_v1_3/sensor/global_sensor_manager.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import 'package:proyecto_imu_v1_3/models/sensor_states.dart';
import '../models/ui_state.dart';

class HomeController extends ChangeNotifier {
  late final GlobalSensorManager _globalSensorManager;
  late AnimationController _pulseAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  UIState _uiState = const UIState();
  
  // Getters
  GlobalSensorManager get globalSensorManager => _globalSensorManager;
  DataProcessor? get dataProcessor => _globalSensorManager.dataProcessor;
  UIState get uiState => _uiState;
  Animation<double> get pulseAnimation => _pulseAnimation;
  Animation<double> get fadeAnimation => _fadeAnimation;
  
  // Sensor state getters
  bool get isRunning => _globalSensorManager.isRunning;
  SensorState get sensorState => _globalSensorManager.sensorState;
  PositionState get positionState => _globalSensorManager.positionState;
  bool get isManagerInitialized => _globalSensorManager.isInitialized;

  // Inicialización
  void initialize(TickerProvider vsync) {
    // Initialize global sensor manager
    _globalSensorManager = GlobalSensorManager.getInstance();
    _globalSensorManager.initialize();
    
    // Add listener for global sensor updates
    _globalSensorManager.addListener(_onGlobalSensorUpdate);

    // Animaciones
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: vsync,
    )..repeat(reverse: true);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    _fadeAnimationController.forward();
  }

  // Métodos de UI
  void updateSelectedTab(int index) {
    _uiState = _uiState.copyWith(selectedTabIndex: index);
    notifyListeners();
  }

  void updateSelectedWindow(int? windowIndex) {
    _uiState = _uiState.copyWith(selectedWindowIndex: windowIndex);
    notifyListeners();
  }

  void toggleSensors() {
    if (_globalSensorManager.isInitialized) {
      _globalSensorManager.toggleSensors();
      notifyListeners();
    } else {
      debugPrint('Cannot toggle sensors: GlobalSensorManager not initialized');
    }
  }

  void _onGlobalSensorUpdate() {
    final dataProcessor = _globalSensorManager.dataProcessor;
    if (dataProcessor != null) {
      final newWindowCount = dataProcessor.matrizsignalfiltertotal.length;
      if (newWindowCount > _uiState.availableWindows.length) {
        _uiState = _uiState.copyWith(
          availableWindows: List.generate(newWindowCount, (index) => index),
        );
      }
    }
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _fadeAnimationController.dispose();
    
    // Remove listener from global sensor manager
    _globalSensorManager.removeListener(_onGlobalSensorUpdate);
    
    super.dispose();
  }
}
