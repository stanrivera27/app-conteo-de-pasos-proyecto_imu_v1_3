import 'package:flutter/material.dart';

class WindowCard extends StatelessWidget {
  final List<int> availableWindows;
  final int? selectedWindowIndex;
  final Function(int?) onWindowSelected;
  final bool isRunning;

  const WindowCard({
    super.key,
    required this.availableWindows,
    required this.selectedWindowIndex,
    required this.onWindowSelected,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.view_carousel,
            color: const Color(0xFF4ECDC4),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Ventanas:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: availableWindows.length,
              itemBuilder: (context, index) {
                final windowIndex = availableWindows[index];
                final isSelected = selectedWindowIndex == windowIndex;
                
                return GestureDetector(
                  onTap: isRunning ? null : () => onWindowSelected(windowIndex),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? const Color(0xFF4ECDC4).withOpacity(0.2)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                          ? const Color(0xFF4ECDC4)
                          : const Color(0xFF4ECDC4).withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${windowIndex + 1}',
                        style: TextStyle(
                          color: isSelected 
                            ? const Color(0xFF4ECDC4)
                            : Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedWindowIndex != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: isRunning ? null : () => onWindowSelected(null),
              icon: Icon(
                Icons.clear,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
              tooltip: 'Limpiar selección',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
