/// Orientation widgets for navigation arrow with compass cone visualization
/// 
/// This package provides Google Maps-style directional indication for improved
/// navigation user experience in Flutter map applications.
/// 
/// Main components:
/// - [OrientationArrowWidget]: The main widget combining arrow and cone
/// - [OrientationConeConfig]: Configuration for cone appearance and behavior
/// - [OrientationConePainter]: Custom painter for cone rendering
/// - [ConePathCache]: Performance optimization for path caching
/// 
/// Example usage:
/// ```dart
/// OrientationArrowWidget(
///   arrowState: currentArrowState,
///   deviceAngle: deviceAngleInRadians,
///   isTrailPoint: false,
///   config: OrientationConeConfig.light(),
/// )
/// ```

export 'orientation_arrow_widget.dart';
export 'orientation_cone_config.dart';
export 'orientation_cone_painter.dart';
export 'cone_path_cache.dart';