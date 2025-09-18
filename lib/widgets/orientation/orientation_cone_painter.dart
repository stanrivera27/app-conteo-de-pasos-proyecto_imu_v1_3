import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cone_path_cache.dart';
import 'orientation_cone_config.dart';

/// Custom painter for rendering orientation cone with gradients and caching
class OrientationConePainter extends CustomPainter {
  /// Orientation angle in degrees (0-360)
  final double orientationAngle;
  
  /// Configuration for cone appearance
  final OrientationConeConfig config;
  
  /// Whether this is a trail point (affects opacity and size)
  final bool isTrailPoint;
  
  /// Confidence level (0.0 to 1.0) affects opacity
  final double confidence;
  
  /// Animation progress for smooth transitions (0.0 to 1.0)
  final double animationProgress;
  
  /// Device pixel ratio for high-DPI displays
  final double devicePixelRatio;
  
  const OrientationConePainter({
    required this.orientationAngle,
    required this.config,
    this.isTrailPoint = false,
    this.confidence = 1.0,
    this.animationProgress = 1.0,
    this.devicePixelRatio = 1.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Early return if confidence is too low
    if (confidence < config.minConfidence) return;
    
    // Validate inputs
    if (!orientationAngle.isFinite || !confidence.isFinite || !animationProgress.isFinite) {
      debugPrint('Warning: Invalid numeric values in OrientationConePainter');
      return;
    }
    
    if (size.width <= 0 || size.height <= 0) {
      debugPrint('Warning: Invalid size in OrientationConePainter: $size');
      return;
    }
    
    // Calculate center point
    final center = Offset(size.width / 2, size.height / 2);
    
    // Apply transformations
    canvas.save();
    
    try {
      canvas.translate(center.dx, center.dy);
      
      // Scale for device pixel ratio and animation
      final scale = devicePixelRatio * animationProgress;
      if (scale > 0 && scale.isFinite) {
        canvas.scale(scale);
      }
      
      _paintCone(canvas, size);
    } catch (e) {
      debugPrint('Error painting orientation cone: $e');
      // Paint simple fallback indicator
      _paintFallbackIndicator(canvas, size);
    } finally {
      canvas.restore();
    }
  }
  
  /// Paint simple fallback indicator when main painting fails
  void _paintFallbackIndicator(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = config.baseColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset.zero,
        math.min(size.width, size.height) * 0.1,
        paint,
      );
    } catch (e) {
      debugPrint('Error painting fallback indicator: $e');
    }
  }
  
  /// Paint the orientation cone with gradient and border
  void _paintCone(Canvas canvas, Size size) {
    // Calculate cone dimensions based on mode (trail vs active)
    final coneLength = isTrailPoint ? config.trailConeLength : config.coneLength;
    final adjustedLength = coneLength * confidence; // Scale by confidence
    
    // Get cached cone path
    final conePath = ConePathCache.getConePath(
      orientationAngle,
      adjustedLength,
      config.coneAngle,
    );
    
    // Create paint for cone fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Apply gradient or solid color based on configuration
    if (config.useGradientFill) {
      _applyGradientFill(fillPaint, adjustedLength);
    } else {
      _applySolidFill(fillPaint);
    }
    
    // Paint the cone fill
    canvas.drawPath(conePath, fillPaint);
    
    // Paint cone border if border width > 0
    if (config.borderWidth > 0) {
      _paintConeBorder(canvas, conePath);
    }
  }
  
  /// Apply gradient fill to cone paint
  void _applyGradientFill(Paint paint, double coneLength) {
    final gradient = isTrailPoint 
        ? config.createTrailGradient()
        : config.createConeGradient();
    
    // Create gradient shader based on cone length
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: coneLength * 2,
      height: coneLength * 2,
    );
    
    paint.shader = gradient.createShader(rect);
    
    // Apply confidence-based opacity
    final alpha = (255 * confidence * animationProgress).round().clamp(0, 255);
    paint.color = paint.color.withAlpha(alpha);
  }
  
  /// Apply solid color fill to cone paint
  void _applySolidFill(Paint paint) {
    final baseColor = isTrailPoint ? config.trailFillColor : config.fillColor;
    final alpha = (255 * confidence * animationProgress).round().clamp(0, 255);
    paint.color = baseColor.withAlpha(alpha);
  }
  
  /// Paint cone border with appropriate styling
  void _paintConeBorder(Canvas canvas, Path conePath) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Apply border color with confidence-based opacity
    final baseColor = isTrailPoint ? config.trailBorderColor : config.borderColor;
    final alpha = (255 * confidence * animationProgress).round().clamp(0, 255);
    borderPaint.color = baseColor.withAlpha(alpha);
    
    // Draw border
    canvas.drawPath(conePath, borderPaint);
  }
  
  @override
  bool shouldRepaint(covariant OrientationConePainter oldDelegate) {
    return orientationAngle != oldDelegate.orientationAngle ||
           confidence != oldDelegate.confidence ||
           animationProgress != oldDelegate.animationProgress ||
           isTrailPoint != oldDelegate.isTrailPoint ||
           config != oldDelegate.config;
  }
  
  /// Check if the painter needs repainting based on angle threshold
  bool shouldRepaintForAngle(double newAngle, {double threshold = 2.0}) {
    final angleDiff = (newAngle - orientationAngle).abs();
    final normalizedDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;
    return normalizedDiff > threshold;
  }
  
  /// Get estimated paint cost for performance monitoring
  int getEstimatedPaintCost() {
    int cost = 10; // Base cost
    
    if (config.useGradientFill) cost += 15; // Gradient rendering
    if (config.borderWidth > 0) cost += 5; // Border rendering
    if (isTrailPoint) cost += 2; // Trail point processing
    
    return cost;
  }
}

/// Specialized painter for low-performance scenarios
class SimpleOrientationConePainter extends CustomPainter {
  final double orientationAngle;
  final Color color;
  final double opacity;
  final double coneLength;
  final double coneAngle;
  
  const SimpleOrientationConePainter({
    required this.orientationAngle,
    required this.color,
    required this.opacity,
    required this.coneLength,
    required this.coneAngle,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    
    // Simple triangular cone without caching
    final path = Path();
    final radians = orientationAngle * pi / 180;
    final halfAngle = (coneAngle / 2) * pi / 180;
    
    // Calculate vertices
    final tip = Offset(
      center.dx + coneLength * cos(radians),
      center.dy + coneLength * sin(radians),
    );
    
    final left = Offset(
      center.dx + coneLength * cos(radians - halfAngle),
      center.dy + coneLength * sin(radians - halfAngle),
    );
    
    final right = Offset(
      center.dx + coneLength * cos(radians + halfAngle),
      center.dy + coneLength * sin(radians + halfAngle),
    );
    
    // Draw simple triangle
    path.moveTo(center.dx, center.dy);
    path.lineTo(left.dx, left.dy);
    path.lineTo(tip.dx, tip.dy);
    path.lineTo(right.dx, right.dy);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant SimpleOrientationConePainter oldDelegate) {
    return orientationAngle != oldDelegate.orientationAngle ||
           opacity != oldDelegate.opacity;
  }
}