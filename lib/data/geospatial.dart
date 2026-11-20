import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/campus.dart';

/// Local tangent approximation is appropriate for a campus-sized survey.
/// Accuracy and planar distances are meters, never latitude/longitude degrees.
class GeoVertex {
  final double latitude, longitude;
  const GeoVertex(this.latitude, this.longitude);
  factory GeoVertex.fromMap(Map<String, dynamic> m) => GeoVertex(
    (m['latitude'] as num).toDouble(),
    (m['longitude'] as num).toDouble(),
  );
}

BoundaryStatus classifyGeoBoundary(
  GeoVertex position,
  List<GeoVertex> polygon,
  double accuracy,
) {
  const metersPerRadian = 6371000.0;
  Point<double> local(GeoVertex v) => Point(
    (v.longitude - position.longitude) *
        pi /
        180 *
        metersPerRadian *
        cos(position.latitude * pi / 180),
    (v.latitude - position.latitude) * pi / 180 * metersPerRadian,
  );
  return classifyBoundary(
    const Point(0, 0),
    polygon.map(local).toList(),
    accuracy,
  );
}

/// Formats decimal degrees coordinates into standard geographic notation:
/// e.g. "16.46396° N, 80.50738° E"
String formatCoordinatesDD(double lat, double lng) {
  final latDir = lat >= 0 ? 'N' : 'S';
  final lngDir = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(5)}° $latDir, ${lng.abs().toStringAsFixed(5)}° $lngDir';
}

/// Formats coordinates into Degrees, Minutes, Seconds (DMS) notation:
/// e.g. "16° 27' 50.3" N, 80° 30' 26.6" E"
String formatCoordinatesDMS(double lat, double lng) {
  String toDMS(double val, bool isLat) {
    final dir = isLat ? (val >= 0 ? 'N' : 'S') : (val >= 0 ? 'E' : 'W');
    final absVal = val.abs();
    final d = absVal.floor();
    final mFull = (absVal - d) * 60;
    final m = mFull.floor();
    final s = (mFull - m) * 60;
    return '$d° $m\' ${s.toStringAsFixed(1)}" $dir';
  }

  return '${toDMS(lat, true)}, ${toDMS(lng, false)}';
}

/// Returns cardinal direction abbreviation (N, NE, E, SE, S, SW, W, NW) for heading in degrees.
String formatCardinalDirection(double degrees) {
  final deg = (degrees % 360 + 360) % 360;
  if (deg >= 337.5 || deg < 22.5) return 'N';
  if (deg >= 22.5 && deg < 67.5) return 'NE';
  if (deg >= 67.5 && deg < 112.5) return 'E';
  if (deg >= 112.5 && deg < 157.5) return 'SE';
  if (deg >= 157.5 && deg < 202.5) return 'S';
  if (deg >= 202.5 && deg < 247.5) return 'SW';
  if (deg >= 247.5 && deg < 292.5) return 'W';
  return 'NW';
}

/// Formats bearing in degrees into readable compass string, e.g. "45° NE"
String formatBearing(double headingDegrees) {
  final deg = (headingDegrees % 360 + 360) % 360;
  return '${deg.round()}° ${formatCardinalDirection(deg)}';
}

/// Formats distance in meters into human readable text: "85 m" or "1.2 km"
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Formats GPS accuracy in meters into clear quality label
String formatAccuracy(double meters) {
  final rounded = meters.round();
  if (meters <= 15) {
    return '±$rounded m • High GPS Precision';
  } else if (meters <= 45) {
    return '±$rounded m • Moderate Accuracy';
  } else {
    return '±$rounded m • Low Precision Fix';
  }
}

/// Calculates initial bearing in degrees (0..360°) between two geographic coordinates
double calculateBearing(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  final dLng = (endLng - startLng) * pi / 180;
  final lat1Rad = startLat * pi / 180;
  final lat2Rad = endLat * pi / 180;

  final y = sin(dLng) * cos(lat2Rad);
  final x =
      cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);
  final brng = atan2(y, x) * 180 / pi;
  return (brng + 360) % 360;
}

/// Calculates relative turn angle in degrees (-180° to +180°) between incoming and outgoing bearings
double calculateTurnAngle(double incomingBearing, double outgoingBearing) {
  return ((outgoingBearing - incomingBearing + 540) % 360) - 180;
}

enum ManeuverType {
  straight,
  slightRight,
  turnRight,
  sharpRight,
  uTurn,
  sharpLeft,
  turnLeft,
  slightLeft,
  arrival,
}

ManeuverType classifyManeuver(double turnAngleDegrees) {
  final angle = turnAngleDegrees;
  if (angle > 160 || angle < -160) return ManeuverType.uTurn;
  if (angle >= 120) return ManeuverType.sharpRight;
  if (angle >= 45) return ManeuverType.turnRight;
  if (angle >= 20) return ManeuverType.slightRight;
  if (angle <= -120) return ManeuverType.sharpLeft;
  if (angle <= -45) return ManeuverType.turnLeft;
  if (angle <= -20) return ManeuverType.slightLeft;
  return ManeuverType.straight;
}

IconData getManeuverIcon(ManeuverType type) => switch (type) {
  ManeuverType.straight => Icons.straight_rounded,
  ManeuverType.slightRight => Icons.turn_slight_right_rounded,
  ManeuverType.turnRight => Icons.turn_right_rounded,
  ManeuverType.sharpRight => Icons.turn_sharp_right_rounded,
  ManeuverType.uTurn => Icons.u_turn_right_rounded,
  ManeuverType.sharpLeft => Icons.turn_sharp_left_rounded,
  ManeuverType.turnLeft => Icons.turn_left_rounded,
  ManeuverType.slightLeft => Icons.turn_slight_left_rounded,
  ManeuverType.arrival => Icons.place_rounded,
};

String getManeuverText(ManeuverType type, String destination) => switch (type) {
  ManeuverType.straight => 'Continue straight',
  ManeuverType.slightRight => 'Keep right',
  ManeuverType.turnRight => 'Turn right',
  ManeuverType.sharpRight => 'Turn sharp right',
  ManeuverType.uTurn => 'Make a U-turn',
  ManeuverType.sharpLeft => 'Turn sharp left',
  ManeuverType.turnLeft => 'Turn left',
  ManeuverType.slightLeft => 'Keep left',
  ManeuverType.arrival => 'Arrive at $destination',
};
