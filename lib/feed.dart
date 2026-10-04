import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class Advisory {
  const Advisory({
    required this.id,
    required this.level,
    required this.area,
    required this.message,
    required this.sentAtIso,
    required this.channel,
  });

  final String id;
  final String level;
  final String area;
  final String message;
  final String sentAtIso;
  final String channel;

  factory Advisory.fromJson(Map<String, dynamic> json) {
    return Advisory(
      id: '${json['id'] ?? ''}',
      level: '${json['level'] ?? ''}',
      area: '${json['area'] ?? ''}',
      message: '${json['message'] ?? ''}',
      sentAtIso: '${json['sentAtIso'] ?? ''}',
      channel: '${json['channel'] ?? ''}',
    );
  }
}

class TrafficFeed {
  const TrafficFeed({
    required this.level,
    required this.score,
    required this.vehicles,
    required this.siteName,
    required this.cameraId,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.positions,
    required this.stale,
    required this.fps,
    required this.speedKph,
    required this.speedCalibrated,
    required this.motion,
    required this.countedToday,
    required this.flowPerMinute,
    required this.occupancyPct,
    required this.vehicleTypes,
    this.error,
  });

  final String level;
  final int score;
  final int vehicles;
  final String siteName;
  final String cameraId;
  final DateTime? timestamp;
  final double lat;
  final double lng;
  final List<Map<String, dynamic>> positions;
  final bool stale;
  final double? fps;
  final double? speedKph;
  final bool speedCalibrated;
  final String motion;
  final int countedToday;
  final double? flowPerMinute;
  final double? occupancyPct;
  final Map<String, int> vehicleTypes;
  final String? error;

  bool get offline => error != null || stale;

  static TrafficFeed failed(String message) {
    return TrafficFeed(
      level: 'LIGHT',
      score: 0,
      vehicles: 0,
      siteName: 'Villamonte Street Intersection',
      cameraId: 'Camera',
      timestamp: null,
      lat: AppConfig.cameraLat,
      lng: AppConfig.cameraLng,
      positions: const [],
      stale: true,
      fps: null,
      speedKph: null,
      speedCalibrated: false,
      motion: '',
      countedToday: 0,
      flowPerMinute: null,
      occupancyPct: null,
      vehicleTypes: const {},
      error: message,
    );
  }

  factory TrafficFeed.fromJson(Map<String, dynamic> json) {
    final rawLevel = '${json['congestion_level'] ?? 'LIGHT'}'.toUpperCase();
    final level = rawLevel == 'CRITICAL' ? 'HEAVY' : rawLevel;
    final stamp = DateTime.tryParse('${json['timestamp'] ?? ''}');
    final stale = stamp == null || DateTime.now().difference(stamp) > AppConfig.staleAfter;
    final positions = <Map<String, dynamic>>[];
    final rawPositions = json['positions'];
    if (rawPositions is List) {
      for (final item in rawPositions) {
        if (item is Map) positions.add(Map<String, dynamic>.from(item));
      }
    }
    final health = json['health'];
    final fps = health is Map && health['fps'] is num ? (health['fps'] as num).toDouble() : null;
    final speed = json['avg_speed_kph'];
    final totals = json['totals'];
    final flow = json['flow'];
    final types = <String, int>{};
    final rawTypes = json['vehicle_types'];
    if (rawTypes is Map) {
      rawTypes.forEach((key, value) {
        if (value is num) types['$key'] = value.round();
      });
    }

    return TrafficFeed(
      level: level,
      score: (json['congestion_score'] as num?)?.round() ?? 0,
      vehicles: (json['vehicles_in_frame'] as num?)?.round() ??
          (json['vehicle_count'] as num?)?.round() ??
          0,
      siteName: '${json['site_name'] ?? 'Villamonte Street Intersection'}',
      cameraId: '${json['camera_id'] ?? 'Camera'}',
      timestamp: stamp,
      lat: (json['lat'] as num?)?.toDouble() ?? AppConfig.cameraLat,
      lng: (json['lng'] as num?)?.toDouble() ?? AppConfig.cameraLng,
      positions: positions,
      stale: stale,
      fps: fps,
      speedKph: speed is num ? speed.toDouble() : null,
      speedCalibrated: json['speed_calibrated'] == true,
      motion: '${json['motion'] ?? ''}',
      countedToday: totals is Map && totals['today'] is num ? (totals['today'] as num).round() : 0,
      flowPerMinute: flow is Map && flow['per_minute'] is num ? (flow['per_minute'] as num).toDouble() : null,
      occupancyPct: json['occupancy_pct'] is num ? (json['occupancy_pct'] as num).toDouble() : null,
      vehicleTypes: types,
    );
  }
}

class BitcasApi {
  Future<TrafficFeed> fetchTraffic() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/assets/data/congestion.json');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return TrafficFeed.failed('Camera feed unavailable (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return TrafficFeed.failed('Camera feed was not a JSON object');
      return TrafficFeed.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      return TrafficFeed.failed('Cannot reach the dashboard. Check the PC address in lib/config.dart.');
    }
  }

  Future<List<Advisory>> fetchAdvisories() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('${AppConfig.baseUrl}/assets/data/advisories.json?t=$stamp');
    final response = await http.get(uri, headers: const {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Advisories unavailable (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((item) => Advisory.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
