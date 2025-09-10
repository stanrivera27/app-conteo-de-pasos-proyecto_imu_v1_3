import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphBuilder {
  // Método que construye los puntos del gráfico
  List<FlSpot> getGraphData(List<double> data) {
    if (data.isEmpty) return [];

    return List.generate(data.length, (index) {
      // Validación adicional para evitar range errors
      if (index >= data.length) {
        return FlSpot(index.toDouble(), 0.0);
      }
      return FlSpot(index.toDouble(), data[index]);
    });
  }

  // Método que retorna el widget del gráfico mejorado
  Widget buildGraph(List<double> data, {Color color = Colors.blue}) {
    if (data.isEmpty) {
      return SizedBox(
        height: 300,
        child: const Center(
          child: Text(
            'No hay datos para mostrar',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: getGraphData(data),
              isCurved: false,
              dotData: const FlDotData(show: false),
              color: color,
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            // Solo mostrar títulos en el lado izquierdo
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: null, // Permite que fl_chart calcule automáticamente
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Color(0xFF64FFDA), // Color cyan claro
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            // Solo mostrar títulos en la parte inferior
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval:
                    data.length > 10 ? (data.length / 5).ceilToDouble() : null,
                getTitlesWidget: (value, meta) {
                  // Solo mostrar algunos valores para evitar saturación
                  if (value %
                          (data.length > 20 ? (data.length / 5).ceil() : 1) !=
                      0) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Color(0xFF64FFDA), // Color cyan claro
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Ocultar títulos del lado derecho
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            // Ocultar títulos de la parte superior
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: null, // Automático
            verticalInterval:
                data.length > 20 ? (data.length / 5).ceilToDouble() : null,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0xFF37474F).withOpacity(0.3), // Gris tenue
                strokeWidth: 0.8,
                dashArray: [5, 5], // Líneas punteadas
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: const Color(0xFF37474F).withOpacity(0.3), // Gris tenue
                strokeWidth: 0.8,
                dashArray: [5, 5], // Líneas punteadas
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: const Color(
                  0xFF64FFDA,
                ), // Color cyan para el eje izquierdo
                width: 2,
              ),
              bottom: BorderSide(
                color: const Color(
                  0xFF64FFDA,
                ), // Color cyan para el eje inferior
                width: 2,
              ),
              right: BorderSide.none, // Sin borde derecho
              top: BorderSide.none, // Sin borde superior
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    'Índice: ${spot.x.toInt()}\nValor: ${spot.y.toStringAsFixed(4)}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              // Opcional: puedes hacer algo con los toques aquí
            },
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (
              LineChartBarData barData,
              List<int> spotIndexes,
            ) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: color.withOpacity(0.8),
                    strokeWidth: 2,
                    dashArray: [3, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: color,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
          // Configuración de márgenes para mejor visualización
          minX: 0,
          maxX: data.length > 1 ? (data.length - 1).toDouble() : 1,
          minY: null, // Permite que fl_chart calcule automáticamente
          maxY: null, // Permite que fl_chart calcule automáticamente
        ),
      ),
    );
  }
}
