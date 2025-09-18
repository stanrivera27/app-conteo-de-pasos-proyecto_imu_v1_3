import 'dart:math';
import 'package:flutter/material.dart';

/// Performance-optimized cache for orientation cone paths
/// Caches pre-calculated paths for common angles to improve rendering performance
class ConePathCache {
  static final Map<int, Path> _pathCache = {};
  static const int maxCacheSize = 72; // Every 5° = 72 entries for full rotation
  static const int angleStep = 5; // Degrees between cached paths
  
  /// Get cached cone path for given angle, creating if necessary
  static Path getConePath(double angle, double coneLength, double coneAngle) {
    try {
      // Validate inputs
      if (!angle.isFinite || !coneLength.isFinite || !coneAngle.isFinite) {
        debugPrint('Warning: Invalid parameters for cone path: angle=$angle, length=$coneLength, angle=$coneAngle');
        return _createFallbackPath();
      }
      
      if (coneLength <= 0 || coneAngle <= 0 || coneAngle > 180) {
        debugPrint('Warning: Invalid cone dimensions: length=$coneLength, angle=$coneAngle');
        return _createFallbackPath();
      }
      
      // Round angle to nearest cache step (5°)
      final int cacheKey = ((angle / angleStep).round() * angleStep) % 360;
      
      // Create composite key including path dimensions
      final String pathKey = '${cacheKey}_${coneLength.toInt()}_${coneAngle.toInt()}';
      final int hashKey = pathKey.hashCode;
      
      return _pathCache[hashKey] ??= _generateConePath(
        cacheKey.toDouble(), 
        coneLength, 
        coneAngle
      );
    } catch (e) {
      debugPrint('Error getting cone path: $e');
      return _createFallbackPath();
    }
  }
  
  /// Create simple fallback path for error cases
  static Path _createFallbackPath() {
    final path = Path();
    try {
      // Create simple triangle pointing up
      path.moveTo(0, -10);
      path.lineTo(-5, 5);
      path.lineTo(5, 5);
      path.close();
    } catch (e) {
      debugPrint('Error creating fallback path: $e');
      // Return empty path as last resort
    }
    return path;
  }
  
  /// Generate cone path for specific angle and dimensions
  static Path _generateConePath(double angle, double coneLength, double coneAngle) {
    final path = Path();
    
    // Convert angle to radians
    final radians = angle * pi / 180;
    final halfConeAngle = (coneAngle / 2) * pi / 180;
    
    // Calculate cone vertices
    final center = const Offset(0, 0); // Arrow center
    
    // Tip of the cone (pointing in direction of angle)
    final tipX = center.dx + coneLength * cos(radians);
    final tipY = center.dy + coneLength * sin(radians);
    final tip = Offset(tipX, tipY);
    
    // Left edge of cone
    final leftAngle = radians - halfConeAngle;
    final leftX = center.dx + coneLength * cos(leftAngle);
    final leftY = center.dy + coneLength * sin(leftAngle);
    final leftEdge = Offset(leftX, leftY);
    
    // Right edge of cone
    final rightAngle = radians + halfConeAngle;
    final rightX = center.dx + coneLength * cos(rightAngle);
    final rightY = center.dy + coneLength * sin(rightAngle);
    final rightEdge = Offset(rightX, rightY);
    
    // Create triangular cone path
    path.moveTo(center.dx, center.dy);
    path.lineTo(leftEdge.dx, leftEdge.dy);
    path.lineTo(tip.dx, tip.dy);
    path.lineTo(rightEdge.dx, rightEdge.dy);
    path.close();
    
    return path;
  }
  
  /// Clear cache to manage memory usage
  static void clearCache() {
    _pathCache.clear();
  }
  
  /// Get cache statistics for debugging
  static Map<String, int> getCacheStats() {
    return {
      'cached_paths': _pathCache.length,
      'max_cache_size': maxCacheSize,
      'angle_step': angleStep,
    };
  }
  
  /// Clean old cache entries if needed (LRU-style cleanup)
  static void _cleanupCache() {
    if (_pathCache.length > maxCacheSize * 2) {
      // Remove half of the cache entries
      final keysToRemove = _pathCache.keys.take(_pathCache.length ~/ 2).toList();
      for (final key in keysToRemove) {
        _pathCache.remove(key);
      }
    }
  }
  
  /// Validate cache performance and cleanup if needed
  static void validateCache() {
    _cleanupCache();
  }
}