import 'dart:math' as math;

/// Things the app can notice the driver doing. Missions listen for one of them.
enum MissionEvent {
  usage,
  mapView,
  zoom,
  markerTap,
  recenter,
  advisoryOpen,
  logsOpen,
  settingsOpen,
  themeChange,
  alertToggle,
  accountOpen,
}

enum MissionKind { daily, random }

class MissionDef {
  const MissionDef({
    required this.id,
    required this.kind,
    required this.title,
    required this.hint,
    required this.event,
    required this.target,
    required this.reward,
    this.unit = '',
  });

  final String id;
  final MissionKind kind;
  final String title;
  final String hint;
  final MissionEvent event;
  final int target;
  final int reward;
  final String unit;

  String progressLabel(int value) {
    final text = '${math.min(value, target)}/$target';
    return unit.isEmpty ? text : '$text $unit';
  }
}

/// Same every day.
const dailyMissions = <MissionDef>[
  MissionDef(
    id: 'daily_use_15',
    kind: MissionKind.daily,
    title: 'Use the app for 15 minutes',
    hint: 'Time counts only while the app is open on screen.',
    event: MissionEvent.usage,
    target: 15,
    reward: 100,
    unit: 'min',
  ),
  MissionDef(
    id: 'daily_logs',
    kind: MissionKind.daily,
    title: 'Read the advisory log',
    hint: 'Open the Advisories tab once.',
    event: MissionEvent.logsOpen,
    target: 1,
    reward: 30,
  ),
];

/// Three of these are drawn each day.
const randomPool = <MissionDef>[
  MissionDef(
    id: 'rnd_map_3',
    kind: MissionKind.random,
    title: 'Check the live map 3 times',
    hint: 'Go to another tab, then come back to the Map.',
    event: MissionEvent.mapView,
    target: 3,
    reward: 30,
  ),
  MissionDef(
    id: 'rnd_zoom_3',
    kind: MissionKind.random,
    title: 'Zoom the map 3 times',
    hint: 'Use the + and - buttons on the right of the map.',
    event: MissionEvent.zoom,
    target: 3,
    reward: 20,
  ),
  MissionDef(
    id: 'rnd_marker',
    kind: MissionKind.random,
    title: 'Tap the camera marker',
    hint: 'The blue camera pin sits on the road.',
    event: MissionEvent.markerTap,
    target: 1,
    reward: 20,
  ),
  MissionDef(
    id: 'rnd_recenter',
    kind: MissionKind.random,
    title: 'Recenter the map on the camera',
    hint: 'Use the target button in the map controls on the right.',
    event: MissionEvent.recenter,
    target: 1,
    reward: 20,
  ),
  MissionDef(
    id: 'rnd_adv_2',
    kind: MissionKind.random,
    title: 'Open 2 advisories',
    hint: 'Tap an advisory in the log to read it in full.',
    event: MissionEvent.advisoryOpen,
    target: 2,
    reward: 40,
  ),
  MissionDef(
    id: 'rnd_settings',
    kind: MissionKind.random,
    title: 'Visit Settings',
    hint: 'Open the Settings tab.',
    event: MissionEvent.settingsOpen,
    target: 1,
    reward: 10,
  ),
  MissionDef(
    id: 'rnd_theme',
    kind: MissionKind.random,
    title: 'Try a different theme',
    hint: 'Settings > Appearance: pick System, Light or Dark.',
    event: MissionEvent.themeChange,
    target: 1,
    reward: 20,
  ),
  MissionDef(
    id: 'rnd_alerts',
    kind: MissionKind.random,
    title: 'Change an alert setting',
    hint: 'Settings > Notifications: flip any switch.',
    event: MissionEvent.alertToggle,
    target: 1,
    reward: 20,
  ),
  MissionDef(
    id: 'rnd_account',
    kind: MissionKind.random,
    title: 'Open your account',
    hint: 'Tap the person button at the top right of the map.',
    event: MissionEvent.accountOpen,
    target: 1,
    reward: 10,
  ),
];

final Map<String, MissionDef> missionById = {
  for (final m in [...dailyMissions, ...randomPool]) m.id: m,
};

String dayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Same date gives the same picks, so every driver sees the same "random"
/// missions on the same day. [salt] changes the draw for a reroll.
List<String> pickRandomIds(DateTime now, {int salt = 0, Set<String> avoid = const {}, int count = 3}) {
  final seed = now.year * 10000 + now.month * 100 + now.day + salt * 7919;
  final rng = math.Random(seed);
  final pool = randomPool.where((m) => !avoid.contains(m.id)).toList()..shuffle(rng);
  return pool.take(count).map((m) => m.id).toList();
}

/// Everything about today's missions that gets saved on the phone.
class MissionBoard {
  MissionBoard({
    this.day = '',
    Map<String, int>? progress,
    Set<String>? claimed,
    List<String>? randomIds,
    this.usageSeconds = 0,
    this.rerolled = false,
    this.points = 0,
    this.streak = 0,
    this.lastClaimDay = '',
  })  : progress = progress ?? {},
        claimed = claimed ?? {},
        randomIds = randomIds ?? [];

  String day;
  final Map<String, int> progress;
  final Set<String> claimed;
  List<String> randomIds;
  int usageSeconds;
  bool rerolled;
  int points;
  int streak;
  String lastClaimDay;

  Map<String, dynamic> toJson() => {
        'day': day,
        'progress': progress,
        'claimed': claimed.toList(),
        'randomIds': randomIds,
        'usageSeconds': usageSeconds,
        'rerolled': rerolled,
        'points': points,
        'streak': streak,
        'lastClaimDay': lastClaimDay,
      };

  factory MissionBoard.fromJson(Map<String, dynamic> json) {
    final progress = <String, int>{};
    final rawProgress = json['progress'];
    if (rawProgress is Map) {
      rawProgress.forEach((key, value) {
        if (value is num) progress['$key'] = value.round();
      });
    }
    final rawClaimed = json['claimed'];
    final rawIds = json['randomIds'];
    return MissionBoard(
      day: '${json['day'] ?? ''}',
      progress: progress,
      claimed: rawClaimed is List ? rawClaimed.map((e) => '$e').toSet() : <String>{},
      randomIds: rawIds is List ? rawIds.map((e) => '$e').toList() : <String>[],
      usageSeconds: (json['usageSeconds'] as num?)?.round() ?? 0,
      rerolled: json['rerolled'] == true,
      points: (json['points'] as num?)?.round() ?? 0,
      streak: (json['streak'] as num?)?.round() ?? 0,
      lastClaimDay: '${json['lastClaimDay'] ?? ''}',
    );
  }
}
