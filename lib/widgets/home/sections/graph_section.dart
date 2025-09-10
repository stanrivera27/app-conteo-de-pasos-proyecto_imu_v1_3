import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import 'package:proyecto_imu_v1_3/sensor/sensor_manager.dart';
import 'package:proyecto_imu_v1_3/widgets/graphbuilder.dart';
import '../../cards/graph_card.dart';
import '../../common/section_title.dart';

class GraphSection extends StatelessWidget {
  final DataProcessor dataProcessor;
  final SensorManager sensorManager;
  final List<int> availableWindows;
  final int? selectedWindowIndex;
  final Function(int?) onWindowSelected;
  final Animation<double> pulseAnimation;
  final GraphBuilder graphBuilder;

  const GraphSection({
    super.key,
    required this.dataProcessor,
    required this.sensorManager,
    required this.availableWindows,
    required this.selectedWindowIndex,
    required this.onWindowSelected,
    required this.pulseAnimation,
    required this.graphBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (sensorManager.isRunning) ...[
            const SizedBox(height: 16),
            _buildRecordingIndicator(),
          ] else ...[
            if (availableWindows.isNotEmpty) ...[
              _buildWindowSelector(),
              const SizedBox(height: 24),
            ],
            _buildGraphs(),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWindowSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Seleccionar Ventana para Análisis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedWindowIndex,
                hint: Text(
                  'Elige una ventana para visualizar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                dropdownColor: const Color(0xFF1A1E3A),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white.withOpacity(0.7),
                ),
                items: availableWindows.map((index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      'Ventana ${index + 1} (${dataProcessor.pasosPorVentana.length > index ? "${dataProcessor.pasosPorVentana[index]} pasos" : "Sin datos"})',
                    ),
                  );
                }).toList(),
                onChanged: onWindowSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphs() {
    return Column(
      children: [
        // Sección de Acelerómetro
        SectionTitle(
          title: 'Datos del Acelerómetro',
          icon: Icons.speed,
          color: const Color(0xFF667eea),
        ),
        GraphCard(
          title: 'Acelerómetro (Señal Original)',
          data: dataProcessor.accMagnitudeListDesfasada,
          color: const Color(0xFF667eea),
          graphBuilder: graphBuilder,
          peakThreshold: 1.2, // ⭐ umbralPicoSinFiltrar
          valleyThreshold: -0.6, // ⭐ umbralValleSinFiltrar
        ),
        
        // NUEVO: Gráfica para el filtro de 2do orden
        GraphCard(
          title: 'Acelerómetro (Filtro 2do Orden)',
          data: dataProcessor.accMagnitudeListFiltered2ndOrder.sublist(0, dataProcessor.index),
          color: const Color(0xFFF7B733), // Color nuevo para diferenciar
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralPico
          valleyThreshold: -0.5, // ⭐ umbralValle
        ),

        // NUEVO: Gráfica para el filtro de 4to orden
        GraphCard(
          title: 'Acelerómetro (Filtro 4to Orden)',
          data: dataProcessor.accMagnitudeListFiltered4thOrder.sublist(0, dataProcessor.index),
          color: const Color(0xFF8FD9A8), // Color nuevo para diferenciar
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralPico
          valleyThreshold: -0.5, // ⭐ umbralValle
        ),

        GraphCard(
          title: 'Acelerómetro (Filtro 4to Orden + EMA)', // Título actualizado para mayor claridad
          data: dataProcessor.accMagnitudeListFiltered.sublist(0, dataProcessor.index),
          color: const Color(0xFF4ECDC4),
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralPico
          valleyThreshold: -0.5, // ⭐ umbralValle
        ),
        const SizedBox(height: 20),

        // Sección de Giroscopio
        SectionTitle(
          title: 'Datos del Giroscopio',
          icon: Icons.rotate_right,
          color: const Color(0xFFFF6B6B),
        ),
        GraphCard(
          title: 'Giroscopio (Señal Original)',
          data: dataProcessor.gyroMagnitudeListDesfasada,
          color: const Color(0xFFFF6B6B),
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralGyroPico (señal original, más permisivo)
          valleyThreshold: -1.0, // ⭐ Simétrico para valles de gyro
        ),
        GraphCard(
          title: 'Giroscopio (Señal Filtrada)',
          data: dataProcessor.ventanaGyroXYZFiltradaList,
          color: const Color(0xFFFF8E53),
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralGyroPico
          valleyThreshold: -1.0, // ⭐ Simétrico para valles de gyro
        ),
        const SizedBox(height: 20),

        // Sección de Análisis
        SectionTitle(
          title: 'Análisis de Pasos',
          icon: Icons.analytics,
          color: const Color(0xFFFFD93D),
        ),
        GraphCard(
          title: 'Detección: Cruces, Picos y Valles',
          data: dataProcessor.unionCrucesPicosVallesListFiltradoTotal,
          color: const Color(0xFF9C27B0),
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralPico (datos ya procesados)
          valleyThreshold: -0.5, // ⭐ umbralValle (datos ya procesados)
        ),
        GraphCard(
          title: 'Detección: Cruces, Picos y Valles(sin simbolos consecutivos)',
          data: dataProcessor.primeraFilaMatrizOrdenada,
          color: const Color(0xFF9C27B0),
          graphBuilder: graphBuilder,
          peakThreshold: 1.0, // ⭐ umbralPico (datos ya procesados)
          valleyThreshold: -0.5, // ⭐ umbralValle (datos ya procesados)
        ),

        // Gráfico de ventana específica si está seleccionada
        if (selectedWindowIndex != null &&
            dataProcessor.matrizsignalfiltertotal.length > selectedWindowIndex!) ...[
          const SizedBox(height: 20),
          SectionTitle(
            title: 'Ventana Específica',
            icon: Icons.view_module,
            color: const Color(0xFF00BCD4),
          ),
          GraphCard(
            title: 'Ventana ${selectedWindowIndex! + 1} - Análisis Detallado',
            data: dataProcessor.matrizsignalfiltertotal[selectedWindowIndex!],
            color: const Color(0xFF00BCD4),
            graphBuilder: graphBuilder,
            peakThreshold: 1.0, // ⭐ umbralPico (datos estabilizados)
            valleyThreshold: -0.5, // ⭐ umbralValle (datos estabilizados)
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Icon(
                  Icons.show_chart,
                  size: 80,
                  color: Colors.white.withOpacity(0.3),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Grabando datos...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los gráficos se mostrarán cuando detengas la grabación',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}