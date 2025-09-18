import 'package:flutter/material.dart';

/// Configuration class for orientation cone appearance and behavior
class OrientationConeConfig {
  /// Length of the orientation cone in pixels
  final double coneLength;
  
  /// Aperture angle of the cone in degrees (total angle, not half)
  final double coneAngle;
  
  /// Base color for the cone
  final Color baseColor;
  
  /// Base opacity for the cone fill
  final double baseOpacity;
  
  /// Border opacity for the cone outline
  final double borderOpacity;
  
  /// Whether to enable smooth animations
  final bool enableAnimation;
  
  /// Update rate for cone orientation changes
  final Duration updateRate;
  
  /// Minimum confidence threshold to show cone
  final double minConfidence;
  
  /// Scale factor for trail points (should be less than 1.0)
  final double trailScaleFactor;
  
  /// Trail point opacity multiplier
  final double trailOpacityFactor;
  
  /// Whether to show gradient fill in cone
  final bool useGradientFill;
  
  /// Border width for cone outline
  final double borderWidth;
  
  const OrientationConeConfig({
    this.coneLength = 40.0,
    this.coneAngle = 60.0,
    this.baseColor = Colors.blue,
    this.baseOpacity = 0.25,
    this.borderOpacity = 0.5,
    this.enableAnimation = true,
    this.updateRate = const Duration(milliseconds: 100),
    this.minConfidence = 0.1,
    this.trailScaleFactor = 0.5,
    this.trailOpacityFactor = 0.3,
    this.useGradientFill = true,
    this.borderWidth = 1.0,
  });
  
  /// Create configuration for light theme
  factory OrientationConeConfig.light() {
    return const OrientationConeConfig(
      baseColor: Colors.blue,
      baseOpacity: 0.25,
      borderOpacity: 0.5,
      borderWidth: 1.0,
    );
  }
  
  /// Create configuration for dark theme
  factory OrientationConeConfig.dark() {
    return const OrientationConeConfig(
      baseColor: Colors.cyan,
      baseOpacity: 0.3,
      borderOpacity: 0.6,
      borderWidth: 1.5,
    );
  }
  
  /// Create configuration for high contrast accessibility
  factory OrientationConeConfig.highContrast() {
    return const OrientationConeConfig(
      baseColor: Colors.blue,
      baseOpacity: 0.4,
      borderOpacity: 0.8,
      borderWidth: 2.0,
      coneAngle: 70.0, // Wider for better visibility
    );
  }
  
  /// Create configuration optimized for performance
  factory OrientationConeConfig.performance() {
    return const OrientationConeConfig(
      enableAnimation: false,
      useGradientFill: false,
      updateRate: Duration(milliseconds: 200),
      borderWidth: 1.0,
    );
  }
  
  /// Copy configuration with overrides
  OrientationConeConfig copyWith({
    double? coneLength,
    double? coneAngle,
    Color? baseColor,
    double? baseOpacity,
    double? borderOpacity,
    bool? enableAnimation,
    Duration? updateRate,
    double? minConfidence,
    double? trailScaleFactor,
    double? trailOpacityFactor,
    bool? useGradientFill,
    double? borderWidth,
  }) {
    return OrientationConeConfig(
      coneLength: coneLength ?? this.coneLength,
      coneAngle: coneAngle ?? this.coneAngle,
      baseColor: baseColor ?? this.baseColor,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      enableAnimation: enableAnimation ?? this.enableAnimation,
      updateRate: updateRate ?? this.updateRate,
      minConfidence: minConfidence ?? this.minConfidence,
      trailScaleFactor: trailScaleFactor ?? this.trailScaleFactor,
      trailOpacityFactor: trailOpacityFactor ?? this.trailOpacityFactor,
      useGradientFill: useGradientFill ?? this.useGradientFill,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
  
  /// Get cone fill color with applied opacity
  Color get fillColor => baseColor.withOpacity(baseOpacity);
  
  /// Get cone border color with applied opacity
  Color get borderColor => baseColor.withOpacity(borderOpacity);
  
  /// Get scaled cone length for trail points
  double get trailConeLength => coneLength * trailScaleFactor;
  
  /// Get trail fill color with reduced opacity
  Color get trailFillColor => baseColor.withOpacity(baseOpacity * trailOpacityFactor);
  
  /// Get trail border color with reduced opacity
  Color get trailBorderColor => baseColor.withOpacity(borderOpacity * trailOpacityFactor);
  
  /// Create gradient for cone fill
  RadialGradient createConeGradient() {
    if (!useGradientFill) {
      return RadialGradient(
        colors: [fillColor, fillColor],
      );
    }
    
    return RadialGradient(
      center: Alignment.topCenter,
      radius: 1.0,
      colors: [
        baseColor.withOpacity(baseOpacity * 1.2), // Center more opaque
        baseColor.withOpacity(baseOpacity * 0.8), // Middle
        baseColor.withOpacity(baseOpacity * 0.3), // Edges more transparent
        Colors.transparent, // Extremes invisible
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );
  }
  
  /// Create gradient for trail cone fill
  RadialGradient createTrailGradient() {
    if (!useGradientFill) {
      return RadialGradient(
        colors: [trailFillColor, trailFillColor],
      );
    }
    
    return RadialGradient(
      center: Alignment.topCenter,
      radius: 1.0,
      colors: [
        baseColor.withOpacity(baseOpacity * trailOpacityFactor * 0.8),
        baseColor.withOpacity(baseOpacity * trailOpacityFactor * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
  }
  
  /// Validate configuration values
  bool isValid() {
    return coneLength > 0 &&
           coneAngle > 0 && coneAngle <= 180 &&
           baseOpacity >= 0 && baseOpacity <= 1 &&
           borderOpacity >= 0 && borderOpacity <= 1 &&
           minConfidence >= 0 && minConfidence <= 1 &&
           trailScaleFactor > 0 && trailScaleFactor <= 1 &&
           trailOpacityFactor > 0 && trailOpacityFactor <= 1 &&
           borderWidth >= 0;
  }
  
  @override
  String toString() {
    return 'OrientationConeConfig('
           'length: $coneLength, '
           'angle: $coneAngle°, '
           'color: $baseColor, '
           'opacity: $baseOpacity, '
           'animated: $enableAnimation)';
  }
}