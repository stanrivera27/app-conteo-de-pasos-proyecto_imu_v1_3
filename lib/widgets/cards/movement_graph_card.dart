import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:proyecto_imu_v1_3/utils/position_calculator.dart';
import 'dart:math';

/// Widget para mostrar el gráfico de movimiento/recorrido en 2D
class MovementGraphCard extends StatelessWidget {
  final String title;
  final List<double> distancias;
  final List<double> azimuth;
  final Color color;

  const MovementGraphCard({
    super.key,
    required this.title,
    required this.distancias,
    required this.azimuth,
    this.color = const Color(0xFF4ECDC4),
  });

  @override
  Widget build(BuildContext context) {
    if (distancias.isEmpty || azimuth.isEmpty) {
      return _buildEmptyCard();
    }

    // Calcular el recorrido usando PositionCalculator
    final recorrido = PositionCalculator.calcularRecorrido([
      distancias,
      azimuth,
    ]);
    final posicionFinal = PositionCalculator.obtenerPosicionFinal(recorrido);
    final distanciaTotal = PositionCalculator.calcularDistanciaTotal(
      distancias,
    );

    // Extraer coordenadas X e Y
    final xCoords = recorrido[0];
    final yCoords = recorrido[1];

    if (xCoords.isEmpty || yCoords.isEmpty) {
      return _buildEmptyCard();
    }

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
          // Header
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
                  '${distancias.length} pasos',
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

          // Gráfico de movimiento
          Container(
            height: 350,
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
            child: _buildMovementChart(xCoords, yCoords),
          ),

          // Estadísticas del recorrido
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatInfo('Inicio', '(0.0, 0.0)'),
              _buildStatInfo(
                'Final',
                '(${posicionFinal['x']?.toStringAsFixed(1)}, ${posicionFinal['y']?.toStringAsFixed(1)})',
              ),
              _buildStatInfo(
                'Dist. Total',
                '${distanciaTotal.toStringAsFixed(1)} m',
              ),
              _buildStatInfo(
                'Desplazam.',
                '${posicionFinal['distancia']?.toStringAsFixed(1)} m',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Eficiencia de ruta
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.route, color: color.withOpacity(0.8), size: 16),
              const SizedBox(width: 8),
              Text(
                'Eficiencia de ruta: ${_calculateRouteEfficiency(posicionFinal['distancia'] ?? 0.0, distanciaTotal).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementChart(List<double> xCoords, List<double> yCoords) {
    // Crear puntos para el gráfico con validación de límites
    final spots = <FlSpot>[];
    final minLength =
        xCoords.length < yCoords.length ? xCoords.length : yCoords.length;

    for (int i = 0; i < minLength; i++) {
      // Validación adicional para evitar range errors
      if (i >= xCoords.length || i >= yCoords.length) {
        break;
      }

      if (xCoords[i] != 0 || yCoords[i] != 0 || i == 0) {
        spots.add(FlSpot(xCoords[i], yCoords[i]));
      }
    }

    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos de movimiento válidos',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Calcular límites del gráfico con margen
    final allX = spots.map((s) => s.x).toList();
    final allY = spots.map((s) => s.y).toList();

    final minX = allX.reduce(min) - 0.5;
    final maxX = allX.reduce(max) + 0.5;
    final minY = allY.reduce(min) - 0.5;
    final maxY = allY.reduce(max) + 0.5;

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Punto de inicio (verde)
                if (index == 0) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: Colors.green,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                }
                // Punto final (rojo)
                else if (index == spots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: Colors.red,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                }
                // Puntos intermedios
                else {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color.withOpacity(0.8),
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                }
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],

        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,

        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF64FFDA),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF64FFDA),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFF37474F).withOpacity(0.3),
              strokeWidth: 0.8,
              dashArray: [5, 5],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: const Color(0xFF37474F).withOpacity(0.3),
              strokeWidth: 0.8,
              dashArray: [5, 5],
            );
          },
        ),

        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: const Color(0xFF64FFDA), width: 2),
            bottom: BorderSide(color: const Color(0xFF64FFDA), width: 2),
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),

        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'X: ${spot.x.toStringAsFixed(2)}\\nY: ${spot.y.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
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
            ],
          ),
          const SizedBox(height: 40),
          const Icon(Icons.route_outlined, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No hay datos de movimiento disponibles',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  double _calculateRouteEfficiency(double displacement, double totalDistance) {
    if (totalDistance == 0) return 0.0;
    return (displacement / totalDistance) * 100;
  }
}
