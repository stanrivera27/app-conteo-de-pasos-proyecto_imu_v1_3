/// Utility functions for converting azimuth/heading values to cardinal directions
class CompassUtils {
  /// Converts azimuth degrees (0-360) to abbreviated cardinal direction (N, NE, E, etc.)
  static String getCardinalDirection(double azimuth) {
    // Normalize azimuth to 0-360 range
    azimuth = azimuth % 360;
    if (azimuth < 0) azimuth += 360;

    if (azimuth >= 337.5 || azimuth < 22.5) {
      return 'N';
    } else if (azimuth >= 22.5 && azimuth < 67.5) {
      return 'NE';
    } else if (azimuth >= 67.5 && azimuth < 112.5) {
      return 'E';
    } else if (azimuth >= 112.5 && azimuth < 157.5) {
      return 'SE';
    } else if (azimuth >= 157.5 && azimuth < 202.5) {
      return 'S';
    } else if (azimuth >= 202.5 && azimuth < 247.5) {
      return 'SW';
    } else if (azimuth >= 247.5 && azimuth < 292.5) {
      return 'W';
    } else if (azimuth >= 292.5 && azimuth < 337.5) {
      return 'NW';
    }
    return 'N'; // Default fallback
  }

  /// Converts azimuth degrees (0-360) to full Spanish cardinal direction name
  static String getSpanishCardinalDirection(double azimuth) {
    // Normalize azimuth to 0-360 range
    azimuth = azimuth % 360;
    if (azimuth < 0) azimuth += 360;

    if (azimuth >= 337.5 || azimuth < 22.5) {
      return 'Norte';
    } else if (azimuth >= 22.5 && azimuth < 67.5) {
      return 'Noreste';
    } else if (azimuth >= 67.5 && azimuth < 112.5) {
      return 'Este';
    } else if (azimuth >= 112.5 && azimuth < 157.5) {
      return 'Sureste';
    } else if (azimuth >= 157.5 && azimuth < 202.5) {
      return 'Sur';
    } else if (azimuth >= 202.5 && azimuth < 247.5) {
      return 'Suroeste';
    } else if (azimuth >= 247.5 && azimuth < 292.5) {
      return 'Oeste';
    } else if (azimuth >= 292.5 && azimuth < 337.5) {
      return 'Noroeste';
    }
    return 'Norte'; // Default fallback
  }

  /// Gets both abbreviated and Spanish direction in a formatted string
  static String getFormattedDirection(double azimuth) {
    final abbreviated = getCardinalDirection(azimuth);
    final spanish = getSpanishCardinalDirection(azimuth);
    return '$abbreviated ($spanish)';
  }

  /// Gets the compass icon based on azimuth direction
  static String getDirectionIcon(double azimuth) {
    final direction = getCardinalDirection(azimuth);
    switch (direction) {
      case 'N':
        return '↑';
      case 'NE':
        return '↗';
      case 'E':
        return '→';
      case 'SE':
        return '↘';
      case 'S':
        return '↓';
      case 'SW':
        return '↙';
      case 'W':
        return '←';
      case 'NW':
        return '↖';
      default:
        return '↑';
    }
  }
}
