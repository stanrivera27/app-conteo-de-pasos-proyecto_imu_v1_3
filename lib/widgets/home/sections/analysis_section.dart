import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import 'package:proyecto_imu_v1_3/sensor/sensor_manager.dart';
import 'package:proyecto_imu_v1_3/utils/compass_utils.dart';
import '../../cards/stat_card.dart';
import '../../cards/info_card.dart';
import '../../cards/analysis_list_card.dart';
import '../../cards/movement_graph_card.dart';

class AnalysisSection extends StatelessWidget {
  final DataProcessor dataProcessor;
  final SensorManager sensorManager;

  const AnalysisSection({
    super.key,
    required this.dataProcessor,
    required this.sensorManager,
  });

  @override
  Widget build(BuildContext context) {
    // --- NUEVO: Se extrae la cantidad de pasos para usarla en la lista ---
    final int pasosTotales = dataProcessor.matrizPasos[0][2].toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Stats Row
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Pasos Totales',
                  value: '$pasosTotales', // Se usa la variable
                  icon: Icons.directions_walk,
                  color: const Color(0xFF4ECDC4),
                ),
              ),
              const SizedBox(width: 12),
              // --- NUEVO: StatCard para la Distancia Total ---
              Expanded(
                child: StatCard(
                  title: 'Distancia Total (m)',
                  // Se asume que el total está en matrizPasos[0][3]
                  value: dataProcessor.matrizPasos[0][3].toStringAsFixed(2),
                  icon: Icons.map_outlined,
                  color: const Color(0xFF6A82FB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Ventanas',
                  value: '${dataProcessor.pasosPorVentana.length}',
                  icon: Icons.view_module,
                  color: const Color(0xFFFFD93D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tiempo de Pasos Card
          if (dataProcessor.tiempoDePasosList.isNotEmpty)
            InfoCard(
              title: 'Tiempo de Pasos (s)',
              value: dataProcessor.tiempoDePasosList
                  .map((t) => t.toStringAsFixed(2))
                  .join(', '),
              icon: Icons.timer_outlined,
              color: const Color(0xFFFC5C7D),
            ),

          // --- NUEVO: Lista de Longitud de Pasos ---
          if (dataProcessor.longitudDePasosList.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Longitud de Pasos (m)',
              icon: Icons.straighten_outlined,
              color: const Color(0xFF4CAF50),
              // El número de items es la cantidad de pasos contados
              itemCount: dataProcessor.longitudDePasosList.length,
              itemBuilder: (context, index) {
                // Se accede a la lista de longitudes en matrizPasos[2]
                final longitud = dataProcessor.longitudDePasosList[index];
                return Row(
                  children: [
                    Text(
                      'Paso ${index + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${longitud.toStringAsFixed(2)} m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          // -------------------------------------------

          // --- NUEVO: Lista de Orientaciones de Pasos ---
          if (dataProcessor.conteoPasos.averageAzimuthPerStep.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Orientación de Pasos',
              icon: Icons.explore_outlined,
              color: const Color(0xFF9C27B0),
              itemCount: dataProcessor.conteoPasos.averageAzimuthPerStep.length,
              itemBuilder: (context, index) {
                final azimuth =
                    dataProcessor.conteoPasos.averageAzimuthPerStep[index];
                final direction = CompassUtils.getFormattedDirection(azimuth);
                final icon = CompassUtils.getDirectionIcon(azimuth);

                return Row(
                  children: [
                    Text(
                      'Paso ${index + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$icon ${azimuth.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      direction,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          // --- NUEVO: Lista de Patrones de Heading (5 valores por paso) ---
          if (dataProcessor.conteoPasos.headingPatternsPerStep.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Patrones de Heading',
              icon: Icons.grain_outlined,
              color: const Color(0xFFFF7043),
              itemCount:
                  dataProcessor.conteoPasos.headingPatternsPerStep.length,
              itemBuilder: (context, index) {
                final headingPattern =
                    dataProcessor.conteoPasos.headingPatternsPerStep[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paso ${index + 1} - 5 valores de heading:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${headingPattern.map((value) => value.toStringAsFixed(1)).join('°, ')}°',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (index <
                        dataProcessor
                                .conteoPasos
                                .headingPatternsPerStep
                                .length -
                            1)
                      const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],

          // --- NUEVO: Gráfico de Movimiento ---
          if (dataProcessor.conteoPasos.averageAzimuthPerStep.isNotEmpty &&
              dataProcessor.longitudDePasosList.isNotEmpty) ...[
            const SizedBox(height: 16),
            MovementGraphCard(
              title: 'Recorrido de Movimiento (Vista 2D)',
              distancias: dataProcessor.longitudDePasosList,
              azimuth: dataProcessor.conteoPasos.averageAzimuthPerStep,
              color: const Color(0xFF00BCD4),
            ),
          ],
          // -------------------------------------------

          // Pasos por Ventana List
          if (dataProcessor.pasosPorVentana.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Pasos por Ventana',
              icon: Icons.directions_walk,
              color: const Color(0xFF4ECDC4),
              itemCount: dataProcessor.pasosPorVentana.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Text(
                      'Ventana ${index + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${dataProcessor.pasosPorVentana[index]} pasos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          // Muestras Recortadas 1
          if (dataProcessor.unionFiltradorecortadoTotal.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Muestras Recortadas 1',
              icon: Icons.content_cut,
              color: const Color(0xFF6A82FB),
              itemCount: dataProcessor.unionFiltradorecortadoTotal.length,
              itemBuilder: (context, index) {
                return Text(
                  'Muestra ${index + 1}: ${dataProcessor.unionFiltradorecortadoTotal[index].toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                );
              },
            ),
          ],
          // Muestras Recortadas 2
          if (dataProcessor.unionFiltradorecortadoTotal2.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Muestras Recortadas 2',
              icon: Icons.content_cut,
              color: const Color(0xFF6A82FB),
              itemCount: dataProcessor.unionFiltradorecortadoTotal2.length,
              itemBuilder: (context, index) {
                return Text(
                  'Muestra ${index + 1}: ${dataProcessor.unionFiltradorecortadoTotal2[index].toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                );
              },
            ),
          ],

          // Signal Stability Card
          const SizedBox(height: 16),

          // Tiempos Restados
          if (!sensorManager.isRunning &&
              dataProcessor.tiemposRestados.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalysisListCard(
              title: 'Pares de Tiempos Restados (s)',
              icon: Icons.hourglass_empty,
              color: const Color(0xFFF7971E),
              itemCount: dataProcessor.tiemposRestados.length ~/ 2,
              itemBuilder: (context, index) {
                // Validación adicional para evitar range error
                final index1 = index * 2;
                final index2 = index * 2 + 1;

                if (index2 >= dataProcessor.tiemposRestados.length) {
                  return const Text(
                    'Error: Índice fuera de rango',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  );
                }

                final tiempo1 = dataProcessor.tiemposRestados[index1]
                    .toStringAsFixed(2);
                final tiempo2 = dataProcessor.tiemposRestados[index2]
                    .toStringAsFixed(2);
                return Text(
                  'Par ${index + 1}: [$tiempo1, $tiempo2]',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
