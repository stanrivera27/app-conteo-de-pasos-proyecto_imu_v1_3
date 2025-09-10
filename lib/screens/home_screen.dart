import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/widgets/graphbuilder.dart';
import 'package:proyecto_imu_v1_3/controllers/home_controller.dart';
import 'package:proyecto_imu_v1_3/widgets/home/modern_header.dart';
import 'package:proyecto_imu_v1_3/widgets/home/recording_controls.dart';
import 'package:proyecto_imu_v1_3/widgets/home/tab_bar_widget.dart';
import 'package:proyecto_imu_v1_3/widgets/home/sections/sensor_section.dart';
import 'package:proyecto_imu_v1_3/widgets/home/sections/analysis_section.dart';
import 'package:proyecto_imu_v1_3/widgets/home/sections/graph_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  
  late final HomeController _controller;
  final GraphBuilder _graphBuilder = GraphBuilder();

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.initialize(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDataSaved() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Datos guardados exitosamente'),
        backgroundColor: const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _controller.fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // Header moderno
                  SliverToBoxAdapter(
                    child: ModernHeader(
                      isRunning: _controller.isRunning,
                      pulseAnimation: _controller.pulseAnimation,
                      frequency: _controller.globalSensorManager.sensorManager?.frequency ?? 0.0,
                    ),
                  ),

                  // Control de grabación
                  SliverToBoxAdapter(
                    child: RecordingControls(
                      isRunning: _controller.isRunning,
                      onToggleSensors: _controller.toggleSensors,
                      dataProcessor: _controller.dataProcessor ?? _controller.globalSensorManager.dataProcessor!,
                      onDataSaved: _onDataSaved,
                    ),
                  ),

                  // Tabs para diferentes vistas
                  SliverToBoxAdapter(
                    child: TabBarWidget(
                      selectedTabIndex: _controller.uiState.selectedTabIndex,
                      onTabSelected: _controller.updateSelectedTab,
                    ),
                  ),

                  // Contenido según tab seleccionado
                  SliverToBoxAdapter(
                    child: _buildTabContent(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_controller.uiState.selectedTabIndex) {
      case 0:
        return SensorSection(
          sensorManager: _controller.globalSensorManager.sensorManager!,
        );
      case 1:
        return AnalysisSection(
          dataProcessor: _controller.dataProcessor ?? _controller.globalSensorManager.dataProcessor!,
          sensorManager: _controller.globalSensorManager.sensorManager!,
        );
      case 2:
        return GraphSection(
          dataProcessor: _controller.dataProcessor ?? _controller.globalSensorManager.dataProcessor!,
          sensorManager: _controller.globalSensorManager.sensorManager!,
          availableWindows: _controller.uiState.availableWindows,
          selectedWindowIndex: _controller.uiState.selectedWindowIndex,
          onWindowSelected: _controller.updateSelectedWindow,
          pulseAnimation: _controller.pulseAnimation,
          graphBuilder: _graphBuilder,
        );
      default:
        return SensorSection(
          sensorManager: _controller.globalSensorManager.sensorManager!,
        );
    }
  }
}
