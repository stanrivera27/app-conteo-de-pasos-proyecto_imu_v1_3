import 'package:flutter/material.dart';
import 'package:proyecto_imu_v1_3/sensor/data/sensor_processor.dart';
import 'package:proyecto_imu_v1_3/sensor/guardar/savedata.dart';

class RecordingControls extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onToggleSensors;
  final DataProcessor dataProcessor;
  final VoidCallback onDataSaved;

  const RecordingControls({
    super.key,
    required this.isRunning,
    required this.onToggleSensors,
    required this.dataProcessor,
    required this.onDataSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onToggleSensors,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRunning
                        ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                        : [
                            const Color(0xFF667eea),
                            const Color(0xFF764ba2),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isRunning
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF667eea))
                          .withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  isRunning ? 'DETENER SENSORES' : 'INICIAR SENSORES',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          if (!isRunning) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                GuardarDatos.guardarMatrizJson(
                  dataProcessor.matrizordenadatotal,
                  _generarNombreArchivo(),
                );
                onDataSaved();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ECDC4).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.save_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _generarNombreArchivo() {
    final now = DateTime.now();
    return '${now.year}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '-${now.minute.toString().padLeft(2, '0')}'
        '-${now.second.toString().padLeft(2, '0')}';
  }
}
