import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/sensor/sensor_manager.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import '../models/ui_state.dart';

class HomeController extends ChangeNotifier {
  late final SensorManager _sensorManager;
  late final DataProcessor _dataProcessor;
  late AnimationController _pulseAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  UIState _uiState = const UIState();
  
  // Getters
  SensorManager get sensorManager => _sensorManager;
  DataProcessor get dataProcessor => _dataProcessor;
  UIState get uiState => _uiState;
  Animation<double> get pulseAnimation => _pulseAnimation;
  Animation<double> get fadeAnimation => _fadeAnimation;

  // Inicialización
  void initialize(TickerProvider vsync) {
    _dataProcessor = DataProcessor();
    _sensorManager = SensorManager(
      onUpdate: _onSensorDataUpdate,
      dataProcessor: _dataProcessor,
    );

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
    _sensorManager.toggleSensors();
    notifyListeners();
  }

  void _onSensorDataUpdate() {
    final newWindowCount = _dataProcessor.matrizsignalfiltertotal.length;
    if (newWindowCount > _uiState.availableWindows.length) {
      _uiState = _uiState.copyWith(
        availableWindows: List.generate(newWindowCount, (index) => index),
      );
    }
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _fadeAnimationController.dispose();
    _sensorManager.dispose();
    super.dispose();
  }
}
