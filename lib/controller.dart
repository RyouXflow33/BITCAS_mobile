import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'config.dart';
import 'missions.dart';
import 'notice_prefs.dart';

/// One place for everything that is not the map itself: theme, alerts,
/// account (or guest), missions and the usage timer.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode themeMode = ThemeMode.system;
  NoticePrefs notice = const NoticePrefs(alertsEnabled: true, enabledLevels: {'Low', 'Moderate', 'High'});
  Account? account;

  /// 0 is a solid panel. 1 is the desk's see-through glass.
  double glass = 1;

  /// Which base map the driver picked in Settings.
  MapBasemap basemap = MapBasemap.osm;
  MissionBoard board = MissionBoard();
  String version = AppConfig.fallbackVersion;
  String build = AppConfig.fallbackBuild;
  bool ready = false;

  SharedPreferences? _prefs;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = true;

  bool get isGuest => account == null;

  /// Glass is on when the slider is off the Opaque end.
  bool get translucent => glass > 0.04;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _prefs = prefs;

    switch (prefs.getString('themeMode')) {
      case 'light':
        themeMode = ThemeMode.light;
      case 'dark':
        themeMode = ThemeMode.dark;
      default:
        themeMode = ThemeMode.system;
    }
    if (prefs.containsKey('glass')) {
      glass = (prefs.getDouble('glass') ?? 1).clamp(0, 1).toDouble();
    } else {
      glass = (prefs.getBool('translucent') ?? true) ? 1 : 0;
    }
    basemap = MapBasemap.fromName(prefs.getString('basemap'));
    notice = await NoticePrefs.load();
    if (_disposed) return;

    final name = prefs.getString('acctName');
    final email = prefs.getString('acctEmail');
    if (name != null && email != null) account = Account(name: name, email: email);

    final raw = prefs.getString('board');
    if (raw != null) {
      try {
        board = MissionBoard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        board = MissionBoard();
      }
    }

    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {
      // Keep the fallback from AppConfig.
    }
    if (_disposed) return;

    _rollover(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _save();
  }

  // ---- theme and alerts ----

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode) return;
    themeMode = mode;
    notifyListeners();
    await _prefs?.setString('themeMode', mode.name);
    record(MissionEvent.themeChange);
  }

  Future<void> setGlass(double value) async {
    final next = value.clamp(0, 1).toDouble();
    if ((next - glass).abs() < 0.001) return;
    glass = next;
    notifyListeners();
    await _prefs?.setDouble('glass', glass);
  }

  Future<void> setBasemap(MapBasemap value) async {
    if (value == basemap) return;
    basemap = value;
    notifyListeners();
    await _prefs?.setString('basemap', value.name);
  }

  Future<void> setNotice(NoticePrefs next) async {
    notice = next;
    notifyListeners();
    await next.save();
    record(MissionEvent.alertToggle);
  }

  // ---- account ----

  Future<void> signIn({required String email}) {
    return _setAccount(Account(name: nameFromEmail(email), email: email.trim()));
  }

  Future<void> signUp({required String name, required String email}) {
    return _setAccount(Account(name: name.trim(), email: email.trim()));
  }

  Future<void> signOut() async {
    account = null;
    notifyListeners();
    await _prefs?.remove('acctName');
    await _prefs?.remove('acctEmail');
  }

  Future<void> _setAccount(Account next) async {
    account = next;
    notifyListeners();
    await _prefs?.setString('acctName', next.name);
    await _prefs?.setString('acctEmail', next.email);
  }

  // ---- missions ----

  List<MissionDef> get randomMissions =>
      board.randomIds.map((id) => missionById[id]).whereType<MissionDef>().toList();

  List<MissionDef> missionsOf(MissionKind kind) => kind == MissionKind.daily ? dailyMissions : randomMissions;

  List<MissionDef> get activeMissions => [...dailyMissions, ...randomMissions];

  int progressOf(String id) => board.progress[id] ?? 0;

  bool isDone(String id) {
    final def = missionById[id];
    return def != null && progressOf(id) >= def.target;
  }

  bool isClaimed(String id) => board.claimed.contains(id);

  bool canClaim(String id) => !isGuest && isDone(id) && !isClaimed(id);

  int claimableCount([MissionKind? kind]) {
    final list = kind == null ? activeMissions : missionsOf(kind);
    return list.where((m) => canClaim(m.id)).length;
  }

  /// The mission shown in the bar at the top of the map.
  MissionDef? get focusMission {
    for (final m in activeMissions) {
      if (!isDone(m.id)) return m;
    }
    return null;
  }

  int get streak {
    final today = dayKey(DateTime.now());
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (board.lastClaimDay == today || board.lastClaimDay == yesterday) return board.streak;
    return 0;
  }

  /// Tell the missions something happened. Call from event handlers, not from build.
  void record(MissionEvent event, [int amount = 1]) {
    if (!ready || event == MissionEvent.usage) return;
    var changed = false;
    for (final m in activeMissions) {
      if (m.event != event) continue;
      final current = progressOf(m.id);
      if (current >= m.target) continue;
      board.progress[m.id] = math.min(m.target, current + amount);
      changed = true;
    }
    if (changed) {
      _save();
      notifyListeners();
    }
  }

  bool claim(String id) {
    if (isGuest) return false;
    final def = missionById[id];
    if (def == null || !canClaim(id)) return false;
    board.claimed.add(id);
    board.points += def.reward;
    if (def.kind == MissionKind.daily && board.lastClaimDay != board.day) {
      final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
      board.streak = board.lastClaimDay == yesterday ? board.streak + 1 : 1;
      board.lastClaimDay = board.day;
    }
    _save();
    notifyListeners();
    return true;
  }

  /// Swap today's unfinished random missions once per day.
  void rerollRandom() {
    if (board.rerolled) return;
    final keep = board.randomIds.where(board.claimed.contains).toList();
    final dropped = board.randomIds.where((id) => !board.claimed.contains(id)).toSet();
    final fresh = pickRandomIds(
      DateTime.now(),
      salt: 1,
      avoid: board.randomIds.toSet(),
      count: 3 - keep.length,
    );
    for (final id in dropped) {
      board.progress.remove(id);
    }
    board.randomIds = [...keep, ...fresh];
    board.rerolled = true;
    _save();
    notifyListeners();
  }

  void _rollover(DateTime now) {
    final key = dayKey(now);
    if (board.day == key && board.randomIds.isNotEmpty) return;
    board.day = key;
    board.progress.clear();
    board.claimed.clear();
    board.usageSeconds = 0;
    board.rerolled = false;
    board.randomIds = pickRandomIds(now);
  }

  void _tick() {
    if (!_foreground) return;
    final now = DateTime.now();
    var changed = false;
    if (dayKey(now) != board.day) {
      _rollover(now);
      changed = true;
    }
    board.usageSeconds++;
    final minutes = board.usageSeconds ~/ 60;
    for (final m in activeMissions) {
      if (m.event != MissionEvent.usage) continue;
      final next = math.min(m.target, minutes);
      if (progressOf(m.id) != next) {
        board.progress[m.id] = next;
        changed = true;
      }
    }
    if (board.usageSeconds % 15 == 0) _save();
    if (changed) notifyListeners();
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString('board', jsonEncode(board.toJson())));
  }
}

/// Base maps from the desk's Traffic Map control.
enum MapBasemap {
  osm,
  satellite,
  light;

  String get label => switch (this) {
        MapBasemap.osm => 'OpenStreetMap',
        MapBasemap.satellite => 'Satellite',
        MapBasemap.light => 'Light streets',
      };

  static MapBasemap fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return MapBasemap.osm;
  }
}

/// Gives every screen access to the [AppController] and rebuilds on change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
