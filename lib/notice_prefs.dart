import 'package:shared_preferences/shared_preferences.dart';

class NoticePrefs {
  const NoticePrefs({
    required this.alertsEnabled,
    required this.enabledLevels,
  });

  static const levels = ['Low', 'Moderate', 'High'];

  final bool alertsEnabled;
  final Set<String> enabledLevels;

  bool allows(String level) => alertsEnabled && enabledLevels.contains(level);

  NoticePrefs copyWith({bool? alertsEnabled, Set<String>? enabledLevels}) {
    return NoticePrefs(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      enabledLevels: enabledLevels ?? this.enabledLevels,
    );
  }

  static Future<NoticePrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('noticeLevels');
    return NoticePrefs(
      alertsEnabled: prefs.getBool('noticeAlerts') ?? true,
      enabledLevels: stored == null ? levels.toSet() : stored.toSet(),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noticeAlerts', alertsEnabled);
    await prefs.setStringList('noticeLevels', enabledLevels.toList());
  }
}
