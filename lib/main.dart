import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'feed.dart';
import 'notice_prefs.dart';
import 'road.dart';

const _ink = Color(0xFF0B1220);
const _card = Color(0xFF151D2C);
const _line = Color(0xFF2A3648);
const _muted = Color(0xFF93A0B4);
const _blue = Color(0xFF3B82F6);
const _live = Color(0xFF3DDC97);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OneSignal.initialize("564f6ed3-9f7a-4513-8173-706c635905ae");
  OneSignal.Notifications.requestPermission(true);
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BITCAS Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        colorScheme: const ColorScheme.dark(
          primary: _blue,
          surface: _card,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0E1624),
          indicatorColor: const Color(0xFF16324F),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              color: selected ? const Color(0xFF7CB3FF) : _muted,
            );
          }),
        ),
      ),
      home: const DriverHome(),
    );
  }
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _api = BitcasApi();
  final _mapController = MapController();
  TrafficFeed? _feed;
  List<Advisory> _advisories = const [];
  String? _advisoryError;
  NoticePrefs _prefs = const NoticePrefs(alertsEnabled: true, enabledLevels: {'Low', 'Moderate', 'High'});
  Set<String> _seenIds = {};
  int _tab = 0;
  Timer? _mapTimer;
  Timer? _advisoryTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadSeen();
    _listenForPushes();
    _loadMap();
    _loadAdvisories();
    _mapTimer = Timer.periodic(AppConfig.mapPoll, (_) => _loadMap());
    _advisoryTimer = Timer.periodic(AppConfig.advisoryPoll, (_) => _loadAdvisories());
  }

  @override
  void dispose() {
    _mapTimer?.cancel();
    _advisoryTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await NoticePrefs.load();
    if (!mounted) return;
    setState(() => _prefs = prefs);
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _seenIds = (prefs.getStringList('seenAdvisoryIds') ?? []).toSet());
  }

  void _listenForPushes() {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return;
    try {
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        _applyPush(event.notification);
      });
      OneSignal.Notifications.addClickListener((event) {
        _applyPush(event.notification);
        _openAdvisories();
      });
    } catch (_) {
      // The widget test has no OneSignal native plugin.
    }
  }

  void _applyPush(OSNotification notification) {
    final raw = notification.additionalData;
    if (raw != null && mounted) {
      final item = Advisory.fromJson(raw);
      if (item.id.isNotEmpty && !_advisories.any((entry) => entry.id == item.id)) {
        setState(() {
          _advisories = [item, ..._advisories];
          _advisoryError = null;
        });
      }
    }
    _loadAdvisories();
  }

  void _openAdvisories() {
    if (!mounted) return;
    setState(() => _tab = 1);
    _markSeen();
  }

  Future<void> _savePrefs(NoticePrefs next) async {
    setState(() => _prefs = next);
    await next.save();
  }

  Future<void> _loadMap() async {
    final feed = await _api.fetchTraffic();
    if (!mounted) return;
    setState(() => _feed = feed);
  }

  Future<void> _loadAdvisories() async {
    try {
      final list = await _api.fetchAdvisories();
      if (!mounted) return;
      setState(() {
        _advisories = list;
        _advisoryError = null;
      });
      if (_tab == 1) _markSeen();
    } catch (error) {
      if (!mounted) return;
      setState(() => _advisoryError = 'Advisories are unavailable right now.');
    }
  }

  int get _alertCount => _advisories.where((item) => _prefs.allows(item.level) && !_seenIds.contains(item.id)).length;

  Future<void> _markSeen() async {
    final next = {..._seenIds, ..._advisories.map((item) => item.id).where((id) => id.isNotEmpty)};
    if (next.length == _seenIds.length) return;
    _seenIds = next;
    final prefs = await SharedPreferences.getInstance();
    final stored = next.toList();
    if (stored.length > 40) stored.removeRange(0, stored.length - 40);
    await prefs.setStringList('seenAdvisoryIds', stored);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _mapBody(_feed),
      _advisoryBody(),
      _settingsBody(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
          if (index == 1) _markSeen();
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _alertCount > 0,
              label: Text('$_alertCount'),
              child: const Icon(Icons.campaign_outlined),
            ),
            selectedIcon: const Icon(Icons.campaign),
            label: 'Advisories',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _mapBody(TrafficFeed? feed) {
    if (feed == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final color = _levelColor(feed.level);
    final points = villamonteRoad.map((pair) => LatLng(pair[1], pair[0])).toList();
    final anchor = cameraAnchor(feed.lat, feed.lng);
    final dots = <CircleMarker>[];
    for (final position in feed.positions) {
      final placed = projectDetectionOnRoad(position, feed.lat, feed.lng);
      if (placed == null) continue;
      dots.add(CircleMarker(
        point: placed.latLng,
        radius: 7,
        color: color,
        borderColor: const Color(0xFF071018),
        borderStrokeWidth: 2,
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(AppConfig.cameraLat, AppConfig.cameraLng),
            initialZoom: 16.4,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.lgu.bitcas.bitcas_driver',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: color,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                ),
              ],
            ),
            CircleLayer(circles: dots),
            MarkerLayer(
              markers: [
                Marker(
                  point: anchor,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Column(
          children: [
            _header(feed),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _statCard('IN FRAME', '${feed.vehicles}', 'in camera view'),
                  const SizedBox(width: 8),
                  _statCard('CONGESTION', '${feed.score}%', null, valueColor: color),
                  const SizedBox(width: 8),
                  _statCard('LEVEL', feed.level, _levelNote(feed), valueColor: color),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _syncChip(feed),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _siteCard(feed),
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 132,
          child: Column(
            children: [
              _zoomButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
              const SizedBox(height: 8),
              _zoomButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(TrafficFeed feed) {
    final fps = feed.fps == null ? feed.siteName : '${feed.siteName} · ${feed.fps!.round()} FPS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BITCAS Driver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(fps, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          if (!feed.offline) _pill('LIVE', _live),
          IconButton(
            onPressed: () => setState(() => _tab = 2),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notification settings',
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String? note, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 10, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: valueColor ?? Colors.white)),
            if (note != null)
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _syncChip(TrafficFeed feed) {
    final live = !feed.offline;
    final text = feed.error ?? (feed.stale ? 'Camera offline. The last reading is stale.' : 'Vision: Live');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Text(text, style: TextStyle(color: live ? _live : const Color(0xFFF5A524), fontSize: 12)),
      ),
    );
  }

  Widget _siteCard(TrafficFeed feed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feed.cameraId, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(feed.siteName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Dots are vehicles in the camera view, placed along this road. They are not GPS.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: _line)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18)),
      ),
    );
  }

  Widget _advisoryBody() {
    final visible = _advisories.where((item) => _prefs.enabledLevels.contains(item.level)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageTitle('Advisories'),
        if (!_prefs.alertsEnabled)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Phone alerts are off. Turn them on in Settings when you want a notice.', style: TextStyle(color: _muted)),
          ),
        Expanded(child: _advisoryList(visible)),
      ],
    );
  }

  Widget _advisoryList(List<Advisory> visible) {
    if (_advisoryError != null && _advisories.isEmpty) {
      return Center(child: Text(_advisoryError!, style: const TextStyle(color: _muted)));
    }
    if (_advisories.isEmpty) {
      return const Center(child: Text('No advisories yet.', style: TextStyle(color: _muted)));
    }
    if (visible.isEmpty) {
      return const Center(child: Text('No advisories for the levels selected in Settings.', style: TextStyle(color: _muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = visible[index];
        final muted = !_prefs.alertsEnabled;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.level} · ${item.area}', style: TextStyle(fontWeight: FontWeight.w700, color: muted ? _muted : Colors.white)),
              const SizedBox(height: 4),
              Text(item.message, style: const TextStyle(color: _muted)),
              const SizedBox(height: 6),
              Text(_formatAdvisoryTime(item.sentAtIso), style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const _PageTitle('Settings', padded: false),
        const Text(
          'Choose which desk broadcasts this phone treats as alerts. The list updates as soon as you change a switch.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 12),
        _settingSwitch(
          title: 'Phone alerts',
          subtitle: 'Show a badge for new advisories',
          value: _prefs.alertsEnabled,
          onChanged: (value) => _savePrefs(_prefs.copyWith(alertsEnabled: value)),
        ),
        const SizedBox(height: 8),
        ...NoticePrefs.levels.map((level) {
          final enabled = _prefs.enabledLevels.contains(level);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _settingSwitch(
              title: level,
              subtitle: 'Include $level advisories',
              value: enabled,
              onChanged: _prefs.alertsEnabled
                  ? (value) {
                      final next = Set<String>.from(_prefs.enabledLevels);
                      if (value) {
                        next.add(level);
                      } else {
                        next.remove(level);
                      }
                      _savePrefs(_prefs.copyWith(enabledLevels: next));
                    }
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _settingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _formatAdvisoryTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year}, $hour:$minute $suffix';
  }

  String _levelNote(TrafficFeed feed) {
    if (feed.speedCalibrated && feed.speedKph != null) {
      return 'Speed ~${feed.speedKph!.round()} km/h';
    }
    if (feed.motion.isNotEmpty) return feed.motion;
    return 'Speed not calibrated';
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'HEAVY':
        return const Color(0xFFE74C3C);
      case 'MODERATE':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF27AE60);
    }
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.text, {this.padded = true});

  final String text;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padded ? 16 : 0, 8, padded ? 16 : 0, 12),
      child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }
}
