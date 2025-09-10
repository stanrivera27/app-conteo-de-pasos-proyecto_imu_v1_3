import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Represents the current position state with accuracy and timestamp
class PositionState {
  final double x;           // X coordinate in meters
  final double y;           // Y coordinate in meters
  final double angle;       // Current heading in degrees
  final double accuracy;    // Position accuracy estimate (0.0 to 1.0)
  final DateTime timestamp; // Last update timestamp
  
  const PositionState({
    required this.x,
    required this.y,
    required this.angle,
    required this.accuracy,
    required this.timestamp,
  });
  
  /// Create a position state with zero coordinates
  factory PositionState.zero() {
    return PositionState(
      x: 0.0,
      y: 0.0,
      angle: 0.0,
      accuracy: 0.0,
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a position state from position calculator result
  factory PositionState.fromCalculator(Map<String, double> calculatorResult, double heading) {
    return PositionState(
      x: calculatorResult['x'] ?? 0.0,
      y: calculatorResult['y'] ?? 0.0,
      angle: heading,
      accuracy: calculatorResult['distancia'] != null && calculatorResult['distancia']! > 0 ? 0.8 : 0.0,
      timestamp: DateTime.now(),
    );
  }
  
  /// Calculate distance from origin
  double get distanceFromOrigin {
    return x * x + y * y; // Squared distance for performance
  }
  
  /// Get distance from origin (actual distance)
  double get actualDistanceFromOrigin {
    return sqrt(x * x + y * y);
  }
  
  /// Check if position has valid coordinates
  bool get isValid {
    return x.isFinite && y.isFinite && angle.isFinite && accuracy >= 0.0;
  }
  
  /// Create a copy with updated values
  PositionState copyWith({
    double? x,
    double? y,
    double? angle,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return PositionState(
      x: x ?? this.x,
      y: y ?? this.y,
      angle: angle ?? this.angle,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  @override
  String toString() {
    return 'PositionState(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, '
           'angle: ${angle.toStringAsFixed(1)}°, accuracy: ${accuracy.toStringAsFixed(2)})';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionState &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          angle == other.angle &&
          accuracy == other.accuracy;

  @override
  int get hashCode =>
      x.hashCode ^
      y.hashCode ^
      angle.hashCode ^
      accuracy.hashCode;
}

/// Represents the current sensor state and performance metrics
class SensorState {
  final bool isRunning;
  final double frequency;      // Sensor sampling frequency in Hz
  final int stepCount;         // Total step count
  final double totalDistance;  // Total distance traveled in meters
  final List<double> distances; // List of step distances
  final List<double> angles;   // List of step angles/headings
  final DateTime lastUpdate;   // Last sensor data update
  final String healthStatus;   // Sensor health: 'Excellent', 'Good', 'Poor', 'Stopped'
  
  const SensorState({
    required this.isRunning,
    required this.frequency,
    required this.stepCount,
    required this.totalDistance,
    required this.distances,
    required this.angles,
    required this.lastUpdate,
    required this.healthStatus,
  });
  
  /// Create a default sensor state
  factory SensorState.initial() {
    return SensorState(
      isRunning: false,
      frequency: 0.0,
      stepCount: 0,
      totalDistance: 0.0,
      distances: const [],
      angles: const [],
      lastUpdate: DateTime.now(),
      healthStatus: 'Stopped',
    );
  }
  
  /// Create sensor state from performance metrics
  factory SensorState.fromMetrics(Map<String, dynamic> metrics) {
    return SensorState(
      isRunning: metrics['isRunning'] ?? false,
      frequency: (metrics['frequency'] ?? 0.0).toDouble(),
      stepCount: metrics['totalSteps'] ?? 0,
      totalDistance: (metrics['totalDistance'] ?? 0.0).toDouble(),
      distances: (metrics['distances'] as List<dynamic>?)?.cast<double>() ?? [],
      angles: (metrics['angles'] as List<dynamic>?)?.cast<double>() ?? [],
      lastUpdate: DateTime.now(),
      healthStatus: _calculateHealthStatus(metrics['frequency'] ?? 0.0, metrics['isRunning'] ?? false),
    );
  }
  
  /// Calculate health status based on frequency and running state
  static String _calculateHealthStatus(double frequency, bool isRunning) {
    if (!isRunning) return 'Stopped';
    if (frequency < 50) return 'Poor';
    if (frequency < 80) return 'Good';
    return 'Excellent';
  }
  
  /// Check if sensor data is recent (within last 2 seconds)
  bool get isDataRecent {
    return DateTime.now().difference(lastUpdate).inSeconds < 2;
  }
  
  /// Get sensor reliability score (0.0 to 1.0)
  double get reliabilityScore {
    if (!isRunning) return 0.0;
    if (!isDataRecent) return 0.2;
    
    final frequencyScore = (frequency / 100.0).clamp(0.0, 1.0);
    final dataConsistencyScore = distances.length == angles.length ? 1.0 : 0.5;
    
    return (frequencyScore + dataConsistencyScore) / 2.0;
  }
  
  /// Create a copy with updated values
  SensorState copyWith({
    bool? isRunning,
    double? frequency,
    int? stepCount,
    double? totalDistance,
    List<double>? distances,
    List<double>? angles,
    DateTime? lastUpdate,
    String? healthStatus,
  }) {
    return SensorState(
      isRunning: isRunning ?? this.isRunning,
      frequency: frequency ?? this.frequency,
      stepCount: stepCount ?? this.stepCount,
      totalDistance: totalDistance ?? this.totalDistance,
      distances: distances ?? this.distances,
      angles: angles ?? this.angles,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      healthStatus: healthStatus ?? this.healthStatus,
    );
  }
  
  @override
  String toString() {
    return 'SensorState(running: $isRunning, freq: ${frequency.toStringAsFixed(1)}Hz, '
           'steps: $stepCount, distance: ${totalDistance.toStringAsFixed(2)}m, '
           'health: $healthStatus)';
  }
}

/// Represents the arrow state on the map including position and visual properties
class ArrowState {
  final LatLng position;        // Current map position (latitude/longitude)
  final double rotation;        // Arrow rotation angle in degrees (0-360)
  final bool isVisible;         // Whether arrow should be visible
  final double confidence;      // Position confidence (0.0 to 1.0)
  final double scale;           // Arrow scale factor for size
  final PositionState positionState; // Underlying position data
  final DateTime timestamp;     // When this arrow state was created
  final double speed;           // Movement speed in m/s
  final bool isTrailPoint;      // Whether this is part of the trail visualization
  
  const ArrowState({
    required this.position,
    required this.rotation,
    required this.isVisible,
    required this.confidence,
    required this.scale,
    required this.positionState,
    required this.timestamp,
    this.speed = 0.0,
    this.isTrailPoint = false,
  });
  
  /// Create an arrow state with default visibility hidden
  factory ArrowState.hidden(LatLng position) {
    return ArrowState(
      position: position,
      rotation: 0.0,
      isVisible: false,
      confidence: 0.0,
      scale: 1.0,
      positionState: PositionState.zero(),
      timestamp: DateTime.now(),
      speed: 0.0,
      isTrailPoint: false,
    );
  }
  
  /// Create arrow state from position state and map coordinates
  factory ArrowState.fromPosition(
    PositionState positionState,
    LatLng mapPosition, {
    double? customRotation,
    double scale = 1.0,
    double speed = 0.0,
    bool isTrailPoint = false,
  }) {
    final confidence = positionState.accuracy;
    final isVisible = confidence > 0.1; // Only show if we have some confidence
    
    return ArrowState(
      position: mapPosition,
      rotation: customRotation ?? positionState.angle,
      isVisible: isVisible,
      confidence: confidence,
      scale: scale,
      positionState: positionState,
      timestamp: DateTime.now(),
      speed: speed,
      isTrailPoint: isTrailPoint,
    );
  }
  
  /// Get arrow opacity based on confidence
  double get opacity {
    if (!isVisible) return 0.0;
    return (confidence * 0.8 + 0.2).clamp(0.2, 1.0); // Min 20%, max 100%
  }
  
  /// Get arrow size based on confidence and scale
  double get size {
    if (!isVisible) return 0.0;
    final baseSize = isTrailPoint ? 25.0 : 40.0; // Smaller for trail points
    final confidenceMultiplier = (confidence * 0.5 + 0.5).clamp(0.5, 1.0);
    return baseSize * scale * confidenceMultiplier;
  }
  
  /// Check if arrow should be animated
  bool get shouldAnimate {
    return isVisible && confidence > 0.3 && !isTrailPoint;
  }
  
  /// Get trail opacity based on age and confidence
  double get trailOpacity {
    if (!isTrailPoint || !isVisible) return 0.0;
    
    final age = DateTime.now().difference(timestamp).inSeconds;
    final ageFactor = (1.0 - (age / 30.0)).clamp(0.0, 1.0); // Fade over 30 seconds
    final baseOpacity = (confidence * 0.6 + 0.2).clamp(0.2, 0.8);
    
    return baseOpacity * ageFactor;
  }
  
  /// Check if this arrow state is recent enough to display
  bool get isRecent {
    final age = DateTime.now().difference(timestamp).inSeconds;
    return age < (isTrailPoint ? 60 : 10); // Trail points live longer
  }
  
  /// Get movement velocity as a vector
  Map<String, double> get velocityVector {
    if (speed == 0.0) return {'vx': 0.0, 'vy': 0.0};
    
    final radians = rotation * pi / 180;
    return {
      'vx': speed * cos(radians),
      'vy': speed * sin(radians),
    };
  }
  
  /// Get normalized rotation (0-360 degrees)
  double get normalizedRotation {
    return (rotation % 360 + 360) % 360;
  }
  
  /// Calculate rotation difference for smooth animation
  double rotationDifferenceTo(double targetRotation) {
    final normalizedTarget = (targetRotation % 360 + 360) % 360;
    final currentNormalized = normalizedRotation;
    
    var diff = normalizedTarget - currentNormalized;
    
    // Choose shortest rotation path
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    
    return diff;
  }
  
  /// Create a copy with updated values
  ArrowState copyWith({
    LatLng? position,
    double? rotation,
    bool? isVisible,
    double? confidence,
    double? scale,
    PositionState? positionState,
    DateTime? timestamp,
    double? speed,
    bool? isTrailPoint,
  }) {
    return ArrowState(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isVisible: isVisible ?? this.isVisible,
      confidence: confidence ?? this.confidence,
      scale: scale ?? this.scale,
      positionState: positionState ?? this.positionState,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      isTrailPoint: isTrailPoint ?? this.isTrailPoint,
    );
  }
  
  @override
  String toString() {
    return 'ArrowState(pos: ${position.latitude.toStringAsFixed(6)}, '
           '${position.longitude.toStringAsFixed(6)}, '
           'rotation: ${rotation.toStringAsFixed(1)}°, '
           'visible: $isVisible, confidence: ${confidence.toStringAsFixed(2)}, '
           'speed: ${speed.toStringAsFixed(2)}m/s, trail: $isTrailPoint)';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrowState &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          rotation == other.rotation &&
          isVisible == other.isVisible &&
          confidence == other.confidence &&
          scale == other.scale &&
          speed == other.speed &&
          isTrailPoint == other.isTrailPoint;

  @override
  int get hashCode =>
      position.hashCode ^
      rotation.hashCode ^
      isVisible.hashCode ^
      confidence.hashCode ^
      scale.hashCode ^
      speed.hashCode ^
      isTrailPoint.hashCode;
}

/// Grid coordinate conversion utilities
class GridConverter {
  static const double gridScale = 0.1; // 10cm per grid unit
  
  /// Convert meters to grid units
  static double metersToGrid(double meters) {
    return meters / gridScale;
  }
  
  /// Convert grid units to meters
  static double gridToMeters(double gridUnits) {
    return gridUnits * gridScale;
  }
  
  /// Convert position state to grid coordinates
  static Map<String, double> positionToGrid(PositionState position) {
    return {
      'gridX': metersToGrid(position.x),
      'gridY': metersToGrid(position.y),
    };
  }
  
  /// Convert grid coordinates to position state
  static PositionState gridToPosition(double gridX, double gridY, {double angle = 0.0, double accuracy = 1.0}) {
    return PositionState(
      x: gridToMeters(gridX),
      y: gridToMeters(gridY),
      angle: angle,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }
}