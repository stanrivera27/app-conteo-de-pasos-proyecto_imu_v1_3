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
  ArrowState calculateArrowState(PositionState position, LatLng startMapPosition) {
    // Convert position to map coordinates
    final mapPosition = positionToLatLng(position, startMapPosition);
    
    // Create arrow state with appropriate confidence and visibility
    return ArrowState.fromPosition(
      position,
      mapPosition,
      customRotation: position.angle,
      scale: 1.0,
    );
  }
  
  /// Create a path of arrow states from position history
  List<ArrowState> createArrowPath(List<PositionState> positionHistory, LatLng startMapPosition) {
    final arrowStates = <ArrowState>[];
    
    for (int i = 0; i < positionHistory.length; i++) {
      final position = positionHistory[i];
      final arrowState = calculateArrowState(position, startMapPosition);
      
      // Adjust visibility based on position in history
      final isRecent = i >= positionHistory.length - 10; // Show last 10 positions
      final adjustedArrowState = arrowState.copyWith(
        isVisible: isRecent && arrowState.isVisible,
        scale: isRecent ? 1.0 : 0.7, // Smaller scale for older positions
      );
      
      arrowStates.add(adjustedArrowState);
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
  
  /// Generate debug information for troubleshooting
  Map<String, dynamic> debugConversion(PositionState position, LatLng startMapPosition) {
    final gridCoords = positionToGrid(position);
    final mapCoords = positionToLatLng(position, startMapPosition);
    
    return {
      'originalPosition': {
        'x': position.x,
        'y': position.y,
        'angle': position.angle,
      },
      'gridCoordinates': gridCoords,
      'mapCoordinates': {
        'latitude': mapCoords.latitude,
        'longitude': mapCoords.longitude,
      },
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
  /// Calculate smooth rotation transition
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
  
  /// Calculate smooth position transition
  static LatLng calculateSmoothPosition(LatLng currentPosition, LatLng targetPosition, double lerpFactor) {
    final latDiff = targetPosition.latitude - currentPosition.latitude;
    final lngDiff = targetPosition.longitude - currentPosition.longitude;
    
    return LatLng(
      currentPosition.latitude + (latDiff * lerpFactor),
      currentPosition.longitude + (lngDiff * lerpFactor),
    );
  }
  
  /// Calculate arrow scale based on movement speed
  static double calculateScaleFromSpeed(double speed, {double minScale = 0.8, double maxScale = 1.2}) {
    // Normalize speed to 0-1 range (assuming max speed of 2 m/s for walking)
    final normalizedSpeed = (speed / 2.0).clamp(0.0, 1.0);
    
    // Map to scale range
    return minScale + (normalizedSpeed * (maxScale - minScale));
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
}