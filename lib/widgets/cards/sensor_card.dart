import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> values;
  final String magnitude;
  final Color color;
  final String? subtitle; // 🚀 NUEVO: Subtítulo opcional para datos Kalman

  const SensorCard({
    super.key,
    required this.title,
    required this.icon,
    required this.values,
    required this.magnitude,
    required this.color,
    this.subtitle, // 🚀 NUEVO
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            magnitude,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // 🚀 NUEVO: Mostrar subtítulo Kalman si está disponible
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
