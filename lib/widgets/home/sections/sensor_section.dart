import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/sensor/sensor_manager.dart';
import '../../cards/sensor_card.dart';

class SensorSection extends StatelessWidget {
  final SensorManager sensorManager;

  const SensorSection({
    super.key,
    required this.sensorManager,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Acelerómetro Card con datos Kalman
          SensorCard(
            title: 'Acelerómetro',
            icon: Icons.speed,
            values: [
              'X: ${sensorManager.accX.toStringAsFixed(2)} m/s²',
              'Y: ${sensorManager.accY.toStringAsFixed(2)} m/s²',
              'Z: ${sensorManager.accZ.toStringAsFixed(2)} m/s²',
            ],
            magnitude:
                'Magnitud: ${sensorManager.accMagnitude.toStringAsFixed(2)} m/s²',
            // 🚀 NUEVO: Datos Kalman en subtitulo
            subtitle:
                'Kalman: ${sensorManager.kalmanAccMagnitude.toStringAsFixed(2)} m/s²',
            color: const Color(0xFF667eea),
          ),

          const SizedBox(height: 16),

          // Giroscopio Card
          SensorCard(
            title: 'Giroscopio',
            icon: Icons.rotate_right,
            values: [
              'X: ${sensorManager.gyroX.toStringAsFixed(2)} rad/s',
              'Y: ${sensorManager.gyroY.toStringAsFixed(2)} rad/s',
              'Z: ${sensorManager.gyroZ.toStringAsFixed(2)} rad/s',
            ],
            magnitude:
                'Magnitud: ${sensorManager.gyroMagnitude.toStringAsFixed(2)} rad/s',
            color: const Color(0xFFFF6B6B),
          ),

          const SizedBox(height: 16),

          // Brújula Card
          SensorCard(
            title: 'Brújula',
            icon: Icons.explore,
            values: [
              'Heading: ${sensorManager.heading?.toStringAsFixed(1) ?? "N/A"}°',
              'Norte: ${sensorManager.heading != null ? _getCardinalDirection(sensorManager.heading!) : "N/A"}',
            ],
            magnitude: 'Rumbo: ${sensorManager.heading != null ? _getDetailedDirection(sensorManager.heading!) : "N/A"}',
            color: const Color(0xFF4ECDC4),
          ),

          const SizedBox(height: 16),

          // 🚀 NUEVA: Tarjeta de estadísticas Kalman
          

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getCardinalDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return 'N';
  }

  String _getDetailedDirection(double heading) {
    if (heading >= 348.75 || heading < 11.25) return 'Norte';
    if (heading >= 11.25 && heading < 33.75) return 'Norte-Noreste';
    if (heading >= 33.75 && heading < 56.25) return 'Noreste';
    if (heading >= 56.25 && heading < 78.75) return 'Este-Noreste';
    if (heading >= 78.75 && heading < 101.25) return 'Este';
    if (heading >= 101.25 && heading < 123.75) return 'Este-Sureste';
    if (heading >= 123.75 && heading < 146.25) return 'Sureste';
    if (heading >= 146.25 && heading < 168.75) return 'Sur-Sureste';
    if (heading >= 168.75 && heading < 191.25) return 'Sur';
    if (heading >= 191.25 && heading < 213.75) return 'Sur-Suroeste';
    if (heading >= 213.75 && heading < 236.25) return 'Suroeste';
    if (heading >= 236.25 && heading < 258.75) return 'Oeste-Suroeste';
    if (heading >= 258.75 && heading < 281.25) return 'Oeste';
    if (heading >= 281.25 && heading < 303.75) return 'Oeste-Noroeste';
    if (heading >= 303.75 && heading < 326.25) return 'Noroeste';
    if (heading >= 326.25 && heading < 348.75) return 'Norte-Noroeste';
    return 'Norte';
  }
}
