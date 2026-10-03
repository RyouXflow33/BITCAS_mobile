import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const villamonteRoadName = 'Circumferential Road';
const cameraFovMeters = 120.0;
const cameraLaneHalfMeters = 7.0;

/// [lng, lat] pairs, matching the web map's GeoJSON order.
const villamonteRoad = <List<double>>[
  [122.9675934, 10.6642688],
  [122.9668395, 10.6645762],
  [122.9661113, 10.6648988],
  [122.9652753, 10.6652617],
  [122.9646445, 10.6655439],
];

class RoadPoint {
  const RoadPoint(this.latLng, this.className);
  final LatLng latLng;
  final String className;
}

class _Anchor {
  const _Anchor(this.fraction, this.point);
  final double fraction;
  final List<double> point;
}

double _clamp01(double value) {
  if (value.isNaN) return 0.5;
  return value.clamp(0, 1).toDouble();
}

double _lineDistance(List<double> start, List<double> end) {
  return math.sqrt(math.pow(end[0] - start[0], 2) + math.pow(end[1] - start[1], 2));
}

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const toRad = math.pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * toRad) * math.cos(lat2 * toRad) * math.pow(math.sin(dLng / 2), 2);
  return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _polylineLengthMeters(List<List<double>> coordinates) {
  var meters = 0.0;
  for (var index = 0; index < coordinates.length - 1; index++) {
    meters += _haversineMeters(
      coordinates[index][1],
      coordinates[index][0],
      coordinates[index + 1][1],
      coordinates[index + 1][0],
    );
  }
  return meters;
}

_Anchor _closestPoint(List<List<double>> coordinates, double lng, double lat) {
  var bestDistance = double.infinity;
  var best = _Anchor(0.5, coordinates.first);
  final lengths = <double>[];
  var total = 0.0;
  for (var index = 0; index < coordinates.length - 1; index++) {
    final length = _lineDistance(coordinates[index], coordinates[index + 1]);
    lengths.add(length);
    total += length;
  }
  if (total == 0) return best;

  var travelled = 0.0;
  for (var index = 0; index < coordinates.length - 1; index++) {
    final start = coordinates[index];
    final end = coordinates[index + 1];
    final dx = end[0] - start[0];
    final dy = end[1] - start[1];
    final lengthSq = dx * dx + dy * dy;
    final t = lengthSq == 0
        ? 0.0
        : (((lng - start[0]) * dx + (lat - start[1]) * dy) / lengthSq).clamp(0.0, 1.0);
    final point = [start[0] + dx * t, start[1] + dy * t];
    final distance = math.sqrt(math.pow(lng - point[0], 2) + math.pow(lat - point[1], 2));
    if (distance < bestDistance) {
      bestDistance = distance;
      best = _Anchor((travelled + t * lengths[index]) / total, point);
    }
    travelled += lengths[index];
  }
  return best;
}

List<double>? _pointAtFraction(List<List<double>> coordinates, double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  var totalLength = 0.0;
  for (var index = 0; index < coordinates.length - 1; index++) {
    totalLength += _lineDistance(coordinates[index], coordinates[index + 1]);
  }
  var travelled = 0.0;
  final target = totalLength * clamped;
  for (var index = 0; index < coordinates.length - 1; index++) {
    final start = coordinates[index];
    final end = coordinates[index + 1];
    final segmentLength = _lineDistance(start, end);
    if (travelled + segmentLength >= target) {
      final segmentFraction = segmentLength == 0 ? 0.0 : (target - travelled) / segmentLength;
      return [
        start[0] + (end[0] - start[0]) * segmentFraction,
        start[1] + (end[1] - start[1]) * segmentFraction,
      ];
    }
    travelled += segmentLength;
  }
  return coordinates.isEmpty ? null : coordinates.last;
}

double _bearing(double lng1, double lat1, double lng2, double lat2) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _headingAtFraction(List<List<double>> coordinates, double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  var total = 0.0;
  for (var index = 0; index < coordinates.length - 1; index++) {
    total += _lineDistance(coordinates[index], coordinates[index + 1]);
  }
  var travelled = 0.0;
  final target = total * clamped;
  for (var index = 0; index < coordinates.length - 1; index++) {
    final start = coordinates[index];
    final end = coordinates[index + 1];
    final segmentLength = _lineDistance(start, end);
    if (travelled + segmentLength >= target || index == coordinates.length - 2) {
      return _bearing(start[0], start[1], end[0], end[1]);
    }
    travelled += segmentLength;
  }
  return 0;
}

LatLng _offset(double lat, double lng, double bearingDeg, double distanceM) {
  const radius = 6371000.0;
  final bearing = bearingDeg * math.pi / 180;
  final phi1 = lat * math.pi / 180;
  final lambda1 = lng * math.pi / 180;
  final angular = distanceM / radius;
  final phi2 = math.asin(math.sin(phi1) * math.cos(angular) +
      math.cos(phi1) * math.sin(angular) * math.cos(bearing));
  final lambda2 = lambda1 +
      math.atan2(
        math.sin(bearing) * math.sin(angular) * math.cos(phi1),
        math.cos(angular) - math.sin(phi1) * math.sin(phi2),
      );
  return LatLng(phi2 * 180 / math.pi, lambda2 * 180 / math.pi);
}

/// Places a camera-frame centroid on the road. This is not the vehicle's GPS.
RoadPoint? projectDetectionOnRoad(Map<String, dynamic> position, double cameraLat, double cameraLng) {
  final x = _clamp01((position['x'] as num?)?.toDouble() ?? 0.5);
  final rawY = (position['y'] as num?)?.toDouble();
  final useDepth = rawY != null && rawY.isFinite;
  final y = useDepth ? _clamp01(rawY) : 0.5;
  final className = (position['class'] as String?) ?? 'vehicle';

  final length = _polylineLengthMeters(villamonteRoad);
  final fovFraction = length == 0 ? 0.08 : cameraFovMeters / length;
  final anchor = _closestPoint(villamonteRoad, cameraLng, cameraLat);
  final alongOffset = useDepth ? (1 - y) * fovFraction : x * fovFraction;
  final alongFraction = (anchor.fraction + alongOffset).clamp(0.0, 1.0);
  final alongPoint = _pointAtFraction(villamonteRoad, alongFraction);
  if (alongPoint == null) return null;

  final heading = _headingAtFraction(villamonteRoad, alongFraction);
  final lateral = useDepth ? (x - 0.5) * 2 * cameraLaneHalfMeters : 0.0;
  final shifted = _offset(alongPoint[1], alongPoint[0], heading + 90, lateral);
  return RoadPoint(shifted, className);
}

LatLng cameraAnchor(double lat, double lng) {
  final anchor = _closestPoint(villamonteRoad, lng, lat);
  return LatLng(anchor.point[1], anchor.point[0]);
}
