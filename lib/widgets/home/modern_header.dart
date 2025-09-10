import 'package:flutter/material.dart';
import '../common/animated_status_indicator.dart';

class ModernHeader extends StatelessWidget {
  final bool isRunning;
  final Animation<double> pulseAnimation;
  final double frequency;

  const ModernHeader({
    super.key,
    required this.isRunning,
    required this.pulseAnimation,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IMU Monitor',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sensor de movimiento en tiempo real',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Card
          AnimatedStatusIndicator(
            isRunning: isRunning,
            pulseAnimation: pulseAnimation,
            frequency: frequency,
          ),
        ],
      ),
    );
  }
}
