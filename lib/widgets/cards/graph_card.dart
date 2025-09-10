import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/widgets/graphbuilder.dart';
import 'dart:math';

class GraphCard extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color color;
  final GraphBuilder graphBuilder;

  // ⭐ NUEVOS: Umbrales configurables para picos y valles
  final double peakThreshold;
  final double valleyThreshold;

  const GraphCard({
    super.key,
    required this.title,
    required this.data,
    required this.color,
    required this.graphBuilder,
    this.peakThreshold = 0.1, // Umbral mínimo para considerar un pico
    this.valleyThreshold = -0.1, // Umbral máximo para considerar un valle
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Análisis de picos y valles ⭐
    final analysisResults = _analyzePeaksAndValleys(
      data,
      peakThreshold,
      valleyThreshold,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${data.length} puntos',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contenedor del gráfico
          Container(
            height: 280,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: graphBuilder.buildGraph(data, color: color),
          ),

          // Información estadística combinada ⭐
          const SizedBox(height: 12),

          // Información estadística combinada ⭐
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatInfo(
                'Min',
                data.reduce((a, b) => a < b ? a : b).toStringAsFixed(3),
              ),
              _buildStatInfo(
                'Max',
                data.reduce((a, b) => a > b ? a : b).toStringAsFixed(3),
              ),
              _buildStatInfo(
                'Prom. Picos',
                (analysisResults['peaks'] as List<double>).isNotEmpty
                    ? ((analysisResults['peaks'] as List<double>).reduce(
                              (a, b) => a + b,
                            ) /
                            (analysisResults['peaks'] as List<double>).length)
                        .toStringAsFixed(3)
                    : '0.000',
              ),
              _buildStatInfo(
                'Prom. Valles',
                (analysisResults['valleys'] as List<double>).isNotEmpty
                    ? ((analysisResults['valleys'] as List<double>).reduce(
                              (a, b) => a + b,
                            ) /
                            (analysisResults['valleys'] as List<double>).length)
                        .toStringAsFixed(3)
                    : '0.000',
              ),
            ],
          ),

          // ⭐ NUEVA SECCIÓN: Análisis de Picos y Valles
          if (analysisResults['peaks'].isNotEmpty ||
              analysisResults['valleys'].isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Encabezado
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: color.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Análisis de Variabilidad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Métricas de picos y valles
                  Row(
                    children: [
                      // Picos
                      Expanded(
                        child: _buildPeakValleyInfo(
                          'Picos', // Título
                          analysisResults['peaks'].length, // Cantidad de picos
                          analysisResults['peakRange'], // Rango entre picos (max-min)
                          Icons.keyboard_arrow_up, // Ícono ↑
                          Colors.green.withOpacity(0.8), // Color verde
                          'Rango', // Label de la métrica
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      // Valles
                      Expanded(
                        child: _buildPeakValleyInfo(
                          'Valles', // Título
                          analysisResults['valleys']
                              .length, // Cantidad de valles
                          analysisResults['valleyRange'], // Rango entre valles (max-min)
                          Icons.keyboard_arrow_down, // Ícono ↓
                          Colors.red.withOpacity(0.8), // Color rojo
                          'Rango', // Label de la métrica
                        ),
                      ),
                    ],
                  ),

                  // Métricas adicionales
                  if (analysisResults['peaks'].isNotEmpty &&
                      analysisResults['valleys'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSmallMetric(
                          'Rango P-V',
                          (analysisResults['peakValleyRange'] as double).toStringAsFixed(2),
                          Icons.height,
                        ),
                        _buildSmallMetric(
                          'Estabilidad',
                          (analysisResults['stabilityIndex'] as double).toStringAsFixed(2),
                          Icons.balance,
                        ),
                        _buildSmallMetric(
                          'Regularidad',
                          (analysisResults['regularityIndex'] as double).toStringAsFixed(2),
                          Icons.linear_scale,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ⭐ ACTUALIZADO: Widget para mostrar info de picos/valles
  Widget _buildPeakValleyInfo(
    String label,
    int count,
    double range, // ⭐ CAMBIADO: Ahora es rango en lugar de variación
    IconData icon,
    Color iconColor,
    String metricLabel, // ⭐ NUEVO: Label para el tipo de métrica
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '$metricLabel: ${range.toStringAsFixed(3)}', // ⭐ CAMBIADO: Mostrar rango
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  // ⭐ NUEVO: Widget para métricas pequeñas
  Widget _buildSmallMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.6), size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  // ⭐ ACTUALIZADO: Función de análisis con umbrales y rangos
  Map<String, dynamic> _analyzePeaksAndValleys(
    List<double> data,
    double peakThreshold,
    double valleyThreshold,
  ) {
    if (data.length < 5) {
      return {
        'peaks': <double>[],
        'valleys': <double>[],
        'peakRange': 0.0, // ⭐ CAMBIADO: Rango entre picos
        'valleyRange': 0.0, // ⭐ CAMBIADO: Rango entre valles
        'peakValleyRange': 0.0,
        'stabilityIndex': 0.0,
        'regularityIndex': 0.0,
      };
    }

    List<double> peaks = [];
    List<double> valleys = [];
    List<int> peakIndices = [];
    List<int> valleyIndices = [];

    // ⭐ MEJORADO: Detectar picos y valles con umbrales configurables
    for (int i = 2; i < data.length - 2; i++) {
      bool isPeak =
          data[i] > data[i - 1] &&
          data[i] > data[i + 1] &&
          data[i] > data[i - 2] &&
          data[i] > data[i + 2] &&
          data[i] >= peakThreshold; // ⭐ NUEVO: Aplicar umbral de pico

      bool isValley =
          data[i] < data[i - 1] &&
          data[i] < data[i + 1] &&
          data[i] < data[i - 2] &&
          data[i] < data[i + 2] &&
          data[i] <= valleyThreshold; // ⭐ NUEVO: Aplicar umbral de valle

      if (isPeak) {
        peaks.add(data[i]);
        peakIndices.add(i);
      } else if (isValley) {
        valleys.add(data[i]);
        valleyIndices.add(i);
      }
    }

    // ⭐ NUEVO: Calcular rangos entre extremos (lo que realmente querías)
    double peakRange = 0.0;
    double valleyRange = 0.0;

    if (peaks.length >= 2) {
      double maxPeak = peaks.reduce((a, b) => a > b ? a : b);
      double minPeak = peaks.reduce((a, b) => a < b ? a : b);
      peakRange =
          maxPeak - minPeak; // Diferencia entre pico más alto y más bajo
    }

    if (valleys.length >= 2) {
      double maxValley = valleys.reduce((a, b) => a > b ? a : b);
      double minValley = valleys.reduce((a, b) => a < b ? a : b);
      valleyRange =
          maxValley - minValley; // Diferencia entre valle más alto y más bajo
    }

    // Calcular métricas adicionales
    double peakValleyRange = 0.0;
    double stabilityIndex = 0.0;
    double regularityIndex = 0.0;

    if (peaks.isNotEmpty && valleys.isNotEmpty) {
      double maxPeak = peaks.reduce((a, b) => a > b ? a : b);
      double minValley = valleys.reduce((a, b) => a < b ? a : b);
      peakValleyRange = maxPeak - minValley;

      // Índice de estabilidad (basado en la consistencia de rangos)
      double totalRange = peakRange + valleyRange;
      double maxPossibleRange = peakValleyRange * 2;
      if (maxPossibleRange > 0) {
        stabilityIndex = 1.0 - (totalRange / maxPossibleRange);
        stabilityIndex = stabilityIndex.clamp(0.0, 1.0);
      }

      // Índice de regularidad (basado en la distancia entre picos/valles)
      if (peakIndices.length > 1 && valleyIndices.length > 1) {
        List<int> peakDistances = [];
        List<int> valleyDistances = [];

        for (int i = 1; i < peakIndices.length; i++) {
          peakDistances.add(peakIndices[i] - peakIndices[i - 1]);
        }

        for (int i = 1; i < valleyIndices.length; i++) {
          valleyDistances.add(valleyIndices[i] - valleyIndices[i - 1]);
        }

        double peakDistanceVariation = _calculateVariationInt(peakDistances);
        double valleyDistanceVariation = _calculateVariationInt(
          valleyDistances,
        );

        regularityIndex =
            1.0 - ((peakDistanceVariation + valleyDistanceVariation) / 2.0);
        regularityIndex = regularityIndex.clamp(0.0, 1.0);
      }
    }

    return {
      'peaks': peaks,
      'valleys': valleys,
      'peakRange': peakRange, // ⭐ NUEVO: Rango entre picos (max-min)
      'valleyRange': valleyRange, // ⭐ NUEVO: Rango entre valles (max-min)
      'peakValleyRange': peakValleyRange,
      'stabilityIndex': stabilityIndex,
      'regularityIndex': regularityIndex,
    };
  }

 
  // ⭐ NUEVO: Calcular coeficiente de variación para enteros
  double _calculateVariationInt(List<int> values) {
    if (values.length < 2) return 0.0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0.0;

    double sumSquaredDiffs = 0.0;
    for (int value in values) {
      sumSquaredDiffs += pow(value - mean, 2);
    }

    double variance = sumSquaredDiffs / values.length;
    double stdDev = sqrt(variance);

    return stdDev / mean.abs();
  }
}
