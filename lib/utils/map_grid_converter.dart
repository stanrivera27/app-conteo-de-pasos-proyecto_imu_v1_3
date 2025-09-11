import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_imu_v1_3/models/sensor_states.dart';

/// Enhanced grid coordinate conversion system for the map interface
/// Handles conversion between meters, grid coordinates, and LatLng with 10cm precision
class MapGridConverter {
  // Grid configuration constants
  static const double gridScale = 0.1; // 10cm per grid unit
  static const int defaultGridRows = 400;
  
  // Map bounds (should match MapScreen bounds)
  final LatLng startBounds;
  final LatLng endBounds;
  
  // Grid dimensions
  final int numRows;
  final int numCols;
  final double latStep;
  final double lngStep;
  
  MapGridConverter({
    required this.startBounds,
    required this.endBounds,
    int? fixedRows,
  }) : 
    numRows = fixedRows ?? defaultGridRows,
    latStep = (endBounds.latitude - startBounds.latitude) / (fixedRows ?? defaultGridRows),
    lngStep = (endBounds.latitude - startBounds.latitude) / (fixedRows ?? defaultGridRows), // Square grid cells
    numCols = ((endBounds.longitude - startBounds.longitude) / 
              ((endBounds.latitude - startBounds.latitude) / (fixedRows ?? defaultGridRows))).floor();

  /// Convert meters to grid units using 10cm scale
  static double metersToGrid(double meters) {
    return meters / gridScale;
  }
  
  /// Convert grid units to meters using 10cm scale
  static double gridToMeters(double gridUnits) {
    return gridUnits * gridScale;
  }
  
  /// Convert position state (in meters) to grid coordinates
  Map<String, double> positionToGrid(PositionState position) {
    return {
      'gridX': metersToGrid(position.x),
      'gridY': metersToGrid(position.y),
      'rotation': position.angle,
    };
  }
  
  /// Convert grid coordinates to position state (in meters)
  PositionState gridToPosition(double gridX, double gridY, {double angle = 0.0, double accuracy = 1.0}) {
    return PositionState(
      x: gridToMeters(gridX),
      y: gridToMeters(gridY),
      angle: angle,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }
  
  /// Convert position state to map coordinates (LatLng)
  LatLng positionToLatLng(PositionState position, LatLng startPosition) {
    // Convert position (meters) to grid coordinates
    final gridCoords = positionToGrid(position);
    
    // Convert grid coordinates to map coordinates
    return gridToLatLng(gridCoords['gridX']!, gridCoords['gridY']!, startPosition);
  }
  
  /// Convert grid coordinates to LatLng map coordinates
  LatLng gridToLatLng(double gridX, double gridY, LatLng startPosition) {
    // Convert grid units back to meters
    final metersX = gridToMeters(gridX);
    final metersY = gridToMeters(gridY);
    
    // Convert meters to lat/lng offset from start position
    final latOffset = metersY / 111320.0; // Approximate meters per degree latitude
    final lngOffset = metersX / (111320.0 * cos(startPosition.latitude * pi / 180)); // Adjust for longitude
    
    return LatLng(
      startPosition.latitude + latOffset,
      startPosition.longitude + lngOffset,
    );
  }
  
  /// Convert LatLng coordinates to grid coordinates
  Map<String, double> latLngToGrid(LatLng point) {
    final row = ((point.latitude - startBounds.latitude) / latStep).floor();
    final col = ((point.longitude - startBounds.longitude) / lngStep).floor();
    
    return {
      'gridX': row.clamp(0, numRows - 1).toDouble(),
      'gridY': col.clamp(0, numCols - 1).toDouble(),
    };
  }
  
  /// Convert grid coordinates to LatLng within map bounds
  LatLng gridCoordsToLatLng(int row, int col) {
    final lat = startBounds.latitude + row * latStep + latStep / 2;
    final lng = startBounds.longitude + col * lngStep + lngStep / 2;
    
    return LatLng(lat, lng);
  }
  
  /// Calculate the optimal arrow position on the map based on current position
  ArrowState calculateArrowState(PositionState position, LatLng startMapPosition, {double? customSpeed, double? compassAngle}) {
    // Convert position to map coordinates
    final mapPosition = positionToLatLng(position, startMapPosition);
    
    // Validate that the position is within map bounds
    if (!isWithinMapBounds(mapPosition)) {
      return ArrowState.hidden(startMapPosition);
    }
    
    // Calculate movement speed if not provided
    final speed = customSpeed ?? 0.0;
    
    // Use compass angle if provided, otherwise use position angle
    // Convert compass angle from radians to degrees if needed
    final rotationAngle = compassAngle != null 
        ? (compassAngle * 180 / pi) // Convert radians to degrees
        : position.angle;
    
    // Create arrow state with appropriate confidence and visibility
    return ArrowState.fromPosition(
      position,
      mapPosition,
      customRotation: rotationAngle,
      scale: ArrowAnimationHelper.calculateScaleFromSpeed(speed),
      speed: speed,
      isTrailPoint: false,
    );
  }
  
  /// Create a path of arrow states from position history with trail management
  List<ArrowState> createArrowPath(List<PositionState> positionHistory, LatLng startMapPosition, {int maxTrailPoints = 50}) {
    final arrowStates = <ArrowState>[];
    
    for (int i = 0; i < positionHistory.length; i++) {
      final position = positionHistory[i];
      final mapPosition = positionToLatLng(position, startMapPosition);
      
      // Skip if position is outside map bounds
      if (!isWithinMapBounds(mapPosition)) continue;
      
      // Calculate speed for this position
      final speed = 0.0; // Simplified for now
      
      final arrowState = ArrowState.fromPosition(
        position,
        mapPosition,
        customRotation: position.angle,
        scale: ArrowAnimationHelper.calculateScaleFromSpeed(speed),
        speed: speed,
        isTrailPoint: i < positionHistory.length - 1, // Only last position is not a trail point
      );
      
      // Adjust visibility and opacity based on position in history
      final isRecent = i >= positionHistory.length - maxTrailPoints;
      if (isRecent && arrowState.isVisible) {
        arrowStates.add(arrowState);
      }
    }
    
    return arrowStates;
  }
  
  /// Calculate grid cell polygon for visualization
  List<LatLng> getGridCellPolygon(int row, int col) {
    final north = startBounds.latitude + row * latStep;
    final south = north + latStep;
    final west = startBounds.longitude + col * lngStep;
    final east = west + lngStep;
    
    return [
      LatLng(north, west),
      LatLng(north, east),
      LatLng(south, east),
      LatLng(south, west),
    ];
  }
  
  /// Validate if a grid coordinate is within bounds
  bool isValidGridCoordinate(double gridX, double gridY) {
    return gridX >= 0 && gridX < numRows && gridY >= 0 && gridY < numCols;
  }
  
  /// Validate if a LatLng point is within map bounds
  bool isWithinMapBounds(LatLng point) {
    return point.latitude >= startBounds.latitude &&
           point.latitude <= endBounds.latitude &&
           point.longitude >= startBounds.longitude &&
           point.longitude <= endBounds.longitude;
  }
  
  /// Calculate distance between two positions in meters
  double calculateDistanceMeters(PositionState pos1, PositionState pos2) {
    final dx = pos2.x - pos1.x;
    final dy = pos2.y - pos1.y;
    return sqrt(dx * dx + dy * dy);
  }
  
  /// Calculate distance between two LatLng points in meters (approximate)
  double calculateLatLngDistance(LatLng point1, LatLng point2) {
    final distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
  
  /// Get grid dimensions info
  Map<String, dynamic> getGridInfo() {
    return {
      'numRows': numRows,
      'numCols': numCols,
      'latStep': latStep,
      'lngStep': lngStep,
      'gridScale': gridScale,
      'totalCells': numRows * numCols,
      'mapArea': {
        'latSpan': endBounds.latitude - startBounds.latitude,
        'lngSpan': endBounds.longitude - startBounds.longitude,
      },
    };
  }
  
  /// Get arrow states for rendering (includes current arrow and trail)
  Map<String, dynamic> getArrowRenderingData(ArrowState? currentArrow, List<ArrowState> trail) {
    final validTrail = trail.where((state) => 
      ArrowAnimationHelper.isValidForRendering(state) && state.isRecent
    ).toList();
    
    return {
      'currentArrow': currentArrow != null && ArrowAnimationHelper.isValidForRendering(currentArrow) ? currentArrow : null,
      'trail': validTrail,
      'trailCount': validTrail.length,
      'hasValidArrow': currentArrow?.isVisible == true,
    };
  }
  
  /// Generate debug information for troubleshooting arrow movement
  Map<String, dynamic> debugArrowConversion(PositionState position, LatLng startMapPosition, ArrowState? currentArrow) {
    final gridCoords = positionToGrid(position);
    final mapCoords = positionToLatLng(position, startMapPosition);
    final arrowState = calculateArrowState(position, startMapPosition);
    
    return {
      'originalPosition': {
        'x': position.x,
        'y': position.y,
        'angle': position.angle,
        'accuracy': position.accuracy,
      },
      'gridCoordinates': gridCoords,
      'mapCoordinates': {
        'latitude': mapCoords.latitude,
        'longitude': mapCoords.longitude,
        'withinBounds': isWithinMapBounds(mapCoords),
      },
      'arrowState': {
        'position': '${arrowState.position.latitude}, ${arrowState.position.longitude}',
        'rotation': arrowState.rotation,
        'isVisible': arrowState.isVisible,
        'confidence': arrowState.confidence,
        'scale': arrowState.scale,
        'speed': arrowState.speed,
      },
      'currentArrow': currentArrow != null ? {
        'position': '${currentArrow.position.latitude}, ${currentArrow.position.longitude}',
        'rotation': currentArrow.rotation,
        'isVisible': currentArrow.isVisible,
        'confidence': currentArrow.confidence,
        'scale': currentArrow.scale,
        'speed': currentArrow.speed,
      } : null,
      'startMapPosition': {
        'latitude': startMapPosition.latitude,
        'longitude': startMapPosition.longitude,
      },
      'gridInfo': getGridInfo(),
    };
  }
}

/// Utility class for arrow animation and movement calculations
class ArrowAnimationHelper {
  /// Calculate smooth rotation transition with shortest path
  static double calculateSmoothRotation(double currentRotation, double targetRotation, double lerpFactor) {
    // Normalize angles to 0-360 range
    final current = (currentRotation % 360 + 360) % 360;
    final target = (targetRotation % 360 + 360) % 360;
    
    // Calculate shortest rotation path
    var diff = target - current;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    
    // Apply linear interpolation
    final newRotation = current + (diff * lerpFactor);
    return (newRotation % 360 + 360) % 360;
  }
  
  /// Calculate smooth position transition using linear interpolation
  static LatLng calculateSmoothPosition(LatLng currentPosition, LatLng targetPosition, double lerpFactor) {
    final latDiff = targetPosition.latitude - currentPosition.latitude;
    final lngDiff = targetPosition.longitude - currentPosition.longitude;
    
    return LatLng(
      currentPosition.latitude + (latDiff * lerpFactor),
      currentPosition.longitude + (lngDiff * lerpFactor),
    );
  }
  
  /// Calculate arrow scale based on movement speed with dynamic scaling
  static double calculateScaleFromSpeed(double speed, {double minScale = 0.5, double maxScale = 2.0}) {
    // Stationary: smaller scale (0.8)
    // Walking (0.5-2.0 m/s): normal scale (1.0)
    // Fast movement (>2.0 m/s): larger scale (1.3)
    
    if (speed < 0.1) {
      return 0.8; // Stationary
    } else if (speed < 0.5) {
      // Interpolate between stationary and walking
      final factor = speed / 0.5;
      return 0.8 + (factor * 0.2); // 0.8 to 1.0
    } else if (speed <= 2.0) {
      return 1.0; // Normal walking speed
    } else {
      // Fast movement - scale up to maxScale (but cap at 1.3 for visibility)
      final factor = ((speed - 2.0) / 2.0).clamp(0.0, 1.0);
      return 1.0 + (factor * 0.3); // 1.0 to 1.3
    }
  }
  
  /// Calculate opacity based on position confidence and recency
  static double calculateOpacity(PositionState position, DateTime lastUpdate, {double minOpacity = 0.3}) {
    final confidence = position.accuracy;
    final ageSeconds = DateTime.now().difference(lastUpdate).inSeconds;
    
    // Reduce opacity based on age (fade out after 5 seconds)
    final ageFactor = (1.0 - (ageSeconds / 5.0)).clamp(0.0, 1.0);
    
    // Combine confidence and age factors
    final opacity = confidence * ageFactor;
    
    return opacity.clamp(minOpacity, 1.0);
  }
  
  /// Calculate smooth state transition for ArrowState
  static ArrowState calculateSmoothState(
    ArrowState currentState,
    ArrowState targetState,
    double lerpFactor,
    double currentSpeed,
  ) {
    if (!currentState.isVisible || !targetState.isVisible) {
      return targetState; // Use target state directly if visibility changed
    }
    
    // Smooth position transition
    final smoothPosition = calculateSmoothPosition(
      currentState.position,
      targetState.position,
      lerpFactor,
    );
    
    // Smooth rotation transition
    final smoothRotation = calculateSmoothRotation(
      currentState.rotation,
      targetState.rotation,
      0.4, // Slightly different lerp factor for rotation
    );
    
    // Dynamic scale based on speed
    final animatedScale = calculateScaleFromSpeed(currentSpeed);
    
    // Interpolate confidence
    final smoothConfidence = currentState.confidence + 
        ((targetState.confidence - currentState.confidence) * lerpFactor);
    
    return targetState.copyWith(
      position: smoothPosition,
      rotation: smoothRotation,
      scale: animatedScale,
      confidence: smoothConfidence,
      speed: currentSpeed,
    );
  }
  
  /// Create trail point from arrow state
  static ArrowState createTrailPoint(ArrowState arrowState) {
    return arrowState.copyWith(
      isTrailPoint: true,
      scale: arrowState.scale * 0.7, // Smaller for trail
      timestamp: DateTime.now(),
    );
  }
  
  /// Filter and manage arrow trail with maximum points
  static List<ArrowState> manageArrowTrail(List<ArrowState> currentTrail, ArrowState newState, {int maxPoints = 100}) {
    final updatedTrail = List<ArrowState>.from(currentTrail);
    
    // Add new trail point if position changed significantly
    if (currentTrail.isEmpty || _hasSignificantMovement(currentTrail.last, newState)) {
      updatedTrail.add(createTrailPoint(newState));
    }
    
    // Remove old trail points
    updatedTrail.removeWhere((state) => !state.isRecent);
    
    // Limit trail length
    if (updatedTrail.length > maxPoints) {
      updatedTrail.removeRange(0, updatedTrail.length - maxPoints);
    }
    
    return updatedTrail;
  }
  
  /// Check if there's significant movement between two arrow states
  static bool _hasSignificantMovement(ArrowState state1, ArrowState state2, {double threshold = 0.5}) {
    final distance = Distance();
    final movementDistance = distance.as(LengthUnit.Meter, state1.position, state2.position);
    return movementDistance >= threshold;
  }
  
  /// Calculate interpolated arrow state for smooth animation frames
  static ArrowState interpolateArrowState(ArrowState startState, ArrowState endState, double progress) {
    final interpolatedPosition = calculateSmoothPosition(
      startState.position,
      endState.position,
      progress,
    );
    
    final interpolatedRotation = calculateSmoothRotation(
      startState.rotation,
      endState.rotation,
      progress,
    );
    
    final interpolatedScale = startState.scale + ((endState.scale - startState.scale) * progress);
    final interpolatedConfidence = startState.confidence + ((endState.confidence - startState.confidence) * progress);
    
    return startState.copyWith(
      position: interpolatedPosition,
      rotation: interpolatedRotation,
      scale: interpolatedScale,
      confidence: interpolatedConfidence,
    );
  }
  
  /// Validate arrow state for rendering
  static bool isValidForRendering(ArrowState arrowState) {
    return arrowState.isVisible &&
           arrowState.confidence > 0.1 &&
           arrowState.position.latitude.isFinite &&
           arrowState.position.longitude.isFinite &&
           arrowState.rotation.isFinite &&
           arrowState.scale > 0;
  }
}