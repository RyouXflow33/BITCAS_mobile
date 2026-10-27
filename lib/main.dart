import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'controller.dart';
import 'feed.dart';
import 'missions.dart';
import 'theme.dart';
import 'ui/advisories_screen.dart';
import 'ui/map_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appId = AppConfig.oneSignalAppId.trim();
  if (appId.isNotEmpty) {
    OneSignal.initialize(appId);
    OneSignal.Notifications.requestPermission(true);
  }
  runApp(const DriverApp());
}

class DriverApp extends StatefulWidget {
  const DriverApp({super.key, this.controller});

  /// Pass one in tests. The app makes its own when this is null.
  final AppController? controller;

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  late final AppController _controller = widget.controller ?? AppController();
  final _lightTheme = buildTheme(Brightness.light);
  final _darkTheme = buildTheme(Brightness.dark);

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'BITCAS Driver',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: _controller.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 560),
            themeAnimationCurve: Curves.easeInOutCubic,
            home: _controller.ready ? const DriverHome() : const _Splash(),
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

const _fade = Duration(milliseconds: 560);

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> with TickerProviderStateMixin {
  final _api = BitcasApi();
  final _mapController = MapController();
  TrafficFeed? _feed;
  List<Advisory> _advisories = const [];
  String? _advisoryError;
  Set<String> _seenIds = {};
  int _tab = 0;
  Timer? _mapTimer;
  Timer? _advisoryTimer;
  late final AnimationController _recenterFly = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
  LatLng? _recenterFrom;
  double? _recenterZoom;

  @override
  void initState() {
    super.initState();
    _loadSeen();
    _listenForPushes();
    _loadMap();
    _loadAdvisories();
    _mapTimer = Timer.periodic(AppConfig.mapPoll, (_) => _loadMap());
    _advisoryTimer = Timer.periodic(AppConfig.advisoryPoll, (_) => _loadAdvisories());
    _recenterFly.addListener(_tickRecenter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).record(MissionEvent.mapView);
    });
  }

  @override
  void dispose() {
    _mapTimer?.cancel();
    _advisoryTimer?.cancel();
    _recenterFly.dispose();
    _mapController.dispose();
    super.dispose();
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
        _selectTab(1);
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

  void _selectTab(int index) {
    final app = AppScope.of(context);
    setState(() => _tab = index);
    if (index == 0) app.record(MissionEvent.mapView);
    if (index == 1) {
      app.record(MissionEvent.logsOpen);
      _markSeen();
    }
    if (index == 2) app.record(MissionEvent.settingsOpen);
  }

  void _zoom(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
    AppScope.of(context).record(MissionEvent.zoom);
  }

  void _recenter() {
    final camera = _mapController.camera;
    _recenterFrom = camera.center;
    _recenterZoom = camera.zoom;
    _recenterFly
      ..stop()
      ..forward(from: 0);
    AppScope.of(context).record(MissionEvent.recenter);
  }

  void _tickRecenter() {
    final from = _recenterFrom;
    final fromZoom = _recenterZoom;
    if (!mounted || from == null || fromZoom == null) return;
    const end = LatLng(AppConfig.cameraLat, AppConfig.cameraLng);
    const endZoom = 16.4;
    final t = Curves.easeInOutCubic.transform(_recenterFly.value);
    _mapController.move(
      LatLng(
        from.latitude + (end.latitude - from.latitude) * t,
        from.longitude + (end.longitude - from.longitude) * t,
      ),
      fromZoom + (endZoom - fromZoom) * t,
    );
  }

  void _markerTap() {
    AppScope.of(context).record(MissionEvent.markerTap);
    final feed = _feed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feed == null ? 'Camera' : '${feed.cameraId} · ${feed.siteName}')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final alertCount = _advisories.where((item) => app.notice.allows(item.level) && !_seenIds.contains(item.id)).length;
    final latest = _advisories.isEmpty ? null : _advisories.first;
    final p = Pal.of(context);
    final onPanels = _tab != 0;

    Widget page(int index, Widget child) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: _tab != index,
          child: AnimatedOpacity(
            opacity: _tab == index ? 1 : 0,
            duration: _fade,
            curve: Curves.easeInOutCubic,
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          MapScreen(
            feed: _feed,
            latestAdvisory: latest,
            mapController: _mapController,
            onZoom: _zoom,
            onRecenter: _recenter,
            onMarkerTap: _markerTap,
            onOpenLogs: () => _selectTab(1),
            blurBehind: _tab == 1,
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !onPanels,
              child: AnimatedOpacity(
                opacity: onPanels ? 1 : 0,
                duration: _fade,
                curve: Curves.easeInOutCubic,
                child: Stack(
                  children: [
                    page(1, AdvisoriesScreen(advisories: _advisories, error: _advisoryError)),
                    page(2, ColoredBox(color: p.bg, child: const SettingsScreen())),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: NavPill(index: _tab, onSelect: _selectTab, advisoryBadge: alertCount),
            ),
          ),
        ],
      ),
    );
  }
}
