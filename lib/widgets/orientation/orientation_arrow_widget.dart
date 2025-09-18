import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/sensor_states.dart';
import 'orientation_cone_config.dart';
import 'orientation_cone_painter.dart';
import 'cone_path_cache.dart';

/// Main widget that combines the navigation arrow with orientation cone visualization
/// Provides Google Maps-style directional indication for improved navigation UX
class OrientationArrowWidget extends StatefulWidget {
  /// Current arrow state with position and movement data
  final ArrowState arrowState;
  
  /// Device angle in radians from compass/magnetometer
  final double deviceAngle;
  
  /// Whether this is a trail point (affects size and opacity)
  final bool isTrailPoint;
  
  /// Configuration for cone appearance and behavior
  final OrientationConeConfig config;
  
  /// Whether to use performance optimized rendering
  final bool usePerformanceMode;
  
  const OrientationArrowWidget({
    super.key,
    required this.arrowState,
    required this.deviceAngle,
    this.isTrailPoint = false,
    this.config = const OrientationConeConfig(),
    this.usePerformanceMode = false,
  });
  
  @override
  State<OrientationArrowWidget> createState() => _OrientationArrowWidgetState();
}

class _OrientationArrowWidgetState extends State<OrientationArrowWidget>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  double _lastDeviceAngle = 0.0;
  DateTime _lastUpdateTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _lastDeviceAngle = widget.deviceAngle;
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    // Animation controller for smooth transitions
    _animationController = AnimationController(
      duration: Duration(milliseconds: widget.config.enableAnimation ? 300 : 0),
      vsync: this,
    );
    
    // Pulse animation for active arrow indication
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Rotation animation for smooth orientation changes
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Start continuous animation for active arrows
    if (widget.config.enableAnimation && !widget.isTrailPoint) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(OrientationArrowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if we need to update animations
    if (widget.config.enableAnimation != oldWidget.config.enableAnimation) {
      _updateAnimationState();
    }
    
    // Check for significant angle changes
    final angleDiff = (widget.deviceAngle - _lastDeviceAngle).abs();
    if (angleDiff > 0.1) { // Significant change threshold
      _lastDeviceAngle = widget.deviceAngle;
      _lastUpdateTime = DateTime.now();
      
      // Trigger smooth rotation update
      if (widget.config.enableAnimation && mounted) {
        _animationController.forward(from: 0.0);
      }
    }
  }
  
  void _updateAnimationState() {
    if (widget.config.enableAnimation && !widget.isTrailPoint) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Early return for hidden arrows
    if (!widget.arrowState.isVisible) {
      return const SizedBox.shrink();
    }
    
    // Validate device angle for finite values
    if (!widget.deviceAngle.isFinite) {
      debugPrint('Warning: Invalid device angle detected: ${widget.deviceAngle}');
      return _buildFallbackArrow();
    }
    
    // Use performance mode for trail points or when explicitly requested
    final useSimpleRendering = widget.usePerformanceMode || 
                              widget.isTrailPoint || 
                              widget.arrowState.confidence < 0.3;
    
    try {
      return RepaintBoundary(
        child: SizedBox(
          width: widget.arrowState.size * 1.5, // Account for cone extension
          height: widget.arrowState.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Orientation cone (background layer)
              if (!useSimpleRendering && widget.config.isValid()) 
                _buildOrientationCone(),
              
              // Navigation arrow (foreground layer)
              _buildNavigationArrow(),
              
              // Performance overlay (debug mode only)
              if (widget.usePerformanceMode) _buildPerformanceOverlay(),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building OrientationArrowWidget: $e');
      return _buildFallbackArrow();
    }
  }
  
  /// Build fallback arrow widget for error cases
  Widget _buildFallbackArrow() {
    return SizedBox(
      width: widget.arrowState.size,
      height: widget.arrowState.size,
      child: Transform.rotate(
        angle: widget.arrowState.rotation * pi / 180,
        child: Icon(
          widget.isTrailPoint ? Icons.circle : Icons.navigation,
          color: widget.isTrailPoint 
              ? Colors.blueGrey.withOpacity(0.5)
              : Colors.blue.withOpacity(0.7),
          size: widget.isTrailPoint ? 10 : widget.arrowState.size * 0.6,
        ),
      ),
    );
  }
  
  /// Build the orientation cone visualization
  Widget _buildOrientationCone() {
    return AnimatedBuilder(
      animation: widget.config.enableAnimation ? _animationController : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final deviceAngleDegrees = _normalizeDeviceAngle();
        
        return CustomPaint(
          size: Size(
            widget.arrowState.size * 1.5,
            widget.arrowState.size * 1.5,
          ),
          painter: OrientationConePainter(
            orientationAngle: deviceAngleDegrees,
            config: widget.config,
            isTrailPoint: widget.isTrailPoint,
            confidence: widget.arrowState.confidence,
            animationProgress: _rotationAnimation.value,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          ),
        );
      },
    );
  }
  
  /// Build the navigation arrow icon
  Widget _buildNavigationArrow() {
    return AnimatedBuilder(
      animation: widget.config.enableAnimation ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final arrowScale = widget.arrowState.scale * 
                         (widget.config.enableAnimation && !widget.isTrailPoint 
                          ? _pulseAnimation.value 
                          : 1.0);
        
        return AnimatedOpacity(
          opacity: widget.isTrailPoint 
              ? widget.arrowState.trailOpacity 
              : widget.arrowState.opacity,
          duration: Duration(
            milliseconds: widget.config.enableAnimation ? 200 : 0,
          ),
          child: Transform.scale(
            scale: arrowScale,
            child: Transform.rotate(
              angle: widget.arrowState.rotation * pi / 180,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isTrailPoint 
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isTrailPoint ? Icons.circle : Icons.navigation,
                  color: widget.isTrailPoint 
                      ? Colors.blueGrey.withOpacity(0.7)
                      : Colors.blue,
                  size: widget.isTrailPoint ? 12 : widget.arrowState.size * 0.6,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Build performance monitoring overlay for debugging
  Widget _buildPerformanceOverlay() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'P',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Convert device angle from radians to normalized degrees (0-360)
  double _normalizeDeviceAngle() {
    // Convert radians to degrees
    double degrees = (widget.deviceAngle * 180 / pi) % 360;
    
    // Normalize to 0-360 range
    if (degrees < 0) {
      degrees += 360;
    }
    
    return degrees;
  }
  
  /// Get current animation state for debugging
  Map<String, dynamic> getAnimationState() {
    return {
      'controller_value': _animationController.value,
      'pulse_value': _pulseAnimation.value,
      'rotation_value': _rotationAnimation.value,
      'is_animating': _animationController.isAnimating,
      'last_update': _lastUpdateTime.millisecondsSinceEpoch,
      'device_angle_degrees': _normalizeDeviceAngle(),
    };
  }
}

/// Simplified widget for high-performance scenarios
class SimpleOrientationArrowWidget extends StatelessWidget {
  final ArrowState arrowState;
  final double deviceAngle;
  final bool isTrailPoint;
  final Color coneColor;
  final double coneOpacity;
  
  const SimpleOrientationArrowWidget({
    super.key,
    required this.arrowState,
    required this.deviceAngle,
    this.isTrailPoint = false,
    this.coneColor = Colors.blue,
    this.coneOpacity = 0.3,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!arrowState.isVisible) {
      return const SizedBox.shrink();
    }
    
    final deviceAngleDegrees = (deviceAngle * 180 / pi) % 360;
    
    return RepaintBoundary(
      child: SizedBox(
        width: arrowState.size * 1.2,
        height: arrowState.size * 1.2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Simple cone
            CustomPaint(
              size: Size(arrowState.size * 1.2, arrowState.size * 1.2),
              painter: SimpleOrientationConePainter(
                orientationAngle: deviceAngleDegrees,
                color: coneColor,
                opacity: coneOpacity * arrowState.confidence,
                coneLength: isTrailPoint ? 20.0 : 30.0,
                coneAngle: 60.0,
              ),
            ),
            
            // Simple arrow
            Transform.rotate(
              angle: arrowState.rotation * pi / 180,
              child: Icon(
                isTrailPoint ? Icons.circle : Icons.navigation,
                color: isTrailPoint ? Colors.blueGrey : Colors.blue,
                size: isTrailPoint ? 10 : arrowState.size * 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for managing orientation arrow widgets
class OrientationArrowHelper {
  /// Create appropriate arrow widget based on performance requirements
  static Widget createArrowWidget({
    required ArrowState arrowState,
    required double deviceAngle,
    bool isTrailPoint = false,
    OrientationConeConfig? config,
    bool forcePerformanceMode = false,
  }) {
    // Determine if we should use performance mode
    final usePerformanceMode = forcePerformanceMode ||
                              arrowState.confidence < 0.2 ||
                              isTrailPoint;
    
    if (usePerformanceMode) {
      return SimpleOrientationArrowWidget(
        arrowState: arrowState,
        deviceAngle: deviceAngle,
        isTrailPoint: isTrailPoint,
      );
    }
    
    return OrientationArrowWidget(
      arrowState: arrowState,
      deviceAngle: deviceAngle,
      isTrailPoint: isTrailPoint,
      config: config ?? const OrientationConeConfig(),
      usePerformanceMode: false,
    );
  }
  
  /// Batch create arrow widgets for trail visualization
  static List<Widget> createTrailArrows({
    required List<ArrowState> arrowStates,
    required double deviceAngle,
    OrientationConeConfig? config,
    int maxArrows = 20,
  }) {
    // Take only recent arrows and limit count
    final recentArrows = arrowStates
        .where((state) => state.isRecent && state.isVisible)
        .take(maxArrows)
        .toList();
    
    return recentArrows.map((arrowState) => 
      createArrowWidget(
        arrowState: arrowState,
        deviceAngle: deviceAngle,
        isTrailPoint: true,
        config: config,
        forcePerformanceMode: true, // Always use performance mode for trails
      )
    ).toList();
  }
  
  /// Clean up resources and validate cache
  static void performMaintenance() {
    ConePathCache.validateCache();
  }
}