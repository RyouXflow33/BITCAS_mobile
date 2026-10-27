import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../controller.dart';
import '../feed.dart';
import '../road.dart';
import '../theme.dart';
import 'account_sheet.dart';
import 'missions_sheet.dart';
import 'widgets.dart';

// Dark mode only: invert the tiles and rotate the hue back, so water stays
// blue and parks stay green but the map is dark. Light mode uses the tiles
// as they are.
const _darkTiles = <double>[
  0.5166, -1.287, -0.1296, 0, 229.5, //
  -0.3834, -0.387, -0.1296, 0, 229.5,
  -0.3834, -1.287, 0.7704, 0, 229.5,
  0, 0, 0, 1, 0,
];

const _fade = Duration(milliseconds: 280);
const _noDataColor = Color(0xFF8A8F98);
const _live = Color(0xFF2FA866);

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.feed,
    required this.latestAdvisory,
    required this.mapController,
    required this.onZoom,
    required this.onRecenter,
    required this.onMarkerTap,
    required this.onOpenLogs,
    this.blurBehind = false,
  });

  final TrafficFeed? feed;
  final Advisory? latestAdvisory;
  final MapController mapController;
  final void Function(double delta) onZoom;
  final VoidCallback onRecenter;
  final VoidCallback onMarkerTap;
  final VoidCallback onOpenLogs;

  /// Frost the whole map. Used under the advisory log so the page is blurry, not clear.
  final bool blurBehind;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = p.ink;
    final muted = p.muted;
    final f = feed;
    final live = f != null && !f.offline;
    final color = f != null && !f.offline ? trafficColor(f.level) : _noDataColor;
    final navSpace = MediaQuery.of(context).padding.bottom + 96;

    final dots = <CircleMarker>[];
    if (f != null && !f.offline) {
      for (final position in f.positions) {
        final placed = projectDetectionOnRoad(position, f.lat, f.lng);
        if (placed == null) continue;
        dots.add(CircleMarker(
          point: placed.latLng,
          radius: 5,
          color: color,
          borderColor: Colors.white,
          borderStrokeWidth: 1.5,
        ));
      }
    }
    final roadPoints = villamonteRoad.map((pair) => LatLng(pair[1], pair[0])).toList();
    final anchor = f == null ? const LatLng(AppConfig.cameraLat, AppConfig.cameraLng) : cameraAnchor(f.lat, f.lng);
    final tiles = _tilesFor(app.basemap);
    final darkenTiles = dark && app.basemap != MapBasemap.satellite;

    // Chrome is a child of the map, inside its repaint boundary. A frost
    // filter outside that boundary often cannot see the tiles, so the panel
    // looks solid even when Translucent is on.
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(AppConfig.cameraLat, AppConfig.cameraLng),
        initialZoom: 16.4,
        backgroundColor: dark ? const Color(0xFF0B0C0F) : const Color(0xFFE6E4DF),
      ),
      children: [
        TileLayer(
          key: ValueKey(app.basemap),
          urlTemplate: tiles.url,
          maxNativeZoom: tiles.maxNativeZoom,
          userAgentPackageName: 'ph.lgu.bitcas.bitcas_driver',
          tileBuilder: darkenTiles
              ? (context, tileWidget, tile) => ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_darkTiles),
                    child: tileWidget,
                  )
              : null,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: roadPoints,
              color: color,
              strokeWidth: 4.5,
              borderStrokeWidth: 2.5,
              borderColor: Colors.white,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
          ],
        ),
        CircleLayer(circles: dots),
        MarkerLayer(
          markers: [
            Marker(
              point: anchor,
              width: 30,
              height: 42,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: onMarkerTap,
                child: const CustomPaint(painter: _LeafletPinPainter(), child: SizedBox.expand()),
              ),
            ),
          ],
        ),

        if (!blurBehind) ...[
        Positioned(
          left: 16,
          right: 16,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _Hold(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        RoundBtn(
                          glass: true,
                          size: 46,
                          icon: Icons.assignment_outlined,
                          tooltip: 'Missions',
                          dot: !app.isGuest && app.claimableCount() > 0,
                          onTap: () => showMissionsSheet(context),
                        ),
                        const Spacer(),
                        if (f != null) ...[
                          _livePill(live, ink),
                          const SizedBox(width: 10),
                        ],
                        _accountButton(context, app),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Align(
          alignment: const Alignment(1, -0.22),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _Hold(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundBtn(glass: true, size: 42, icon: Icons.add, tooltip: 'Zoom in', onTap: () => onZoom(1)),
                  const SizedBox(height: 8),
                  RoundBtn(glass: true, size: 42, icon: Icons.remove, tooltip: 'Zoom out', onTap: () => onZoom(-1)),
                  const SizedBox(height: 8),
                  RoundBtn(glass: true, size: 42, icon: Icons.my_location, tooltip: 'Recenter on camera', onTap: onRecenter),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 16,
          right: 16,
          bottom: navSpace,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IgnorePointer(
                child: Text(
                  tiles.credit,
                  style: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                    fontSize: 9,
                    shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Hold(
                child: AnimatedSwitcher(
                  duration: _fade,
                  child: f == null ? _loading() : _card(f, live, color, ink, muted),
                ),
              ),
            ],
          ),
        ),
        ],
        if (blurBehind) Positioned.fill(child: _MapFrost(dark: dark)),
      ],
    );
  }

  Widget _accountButton(BuildContext context, AppController app) {
    if (app.isGuest) {
      return RoundBtn(
        glass: true,
        size: 46,
        icon: Icons.person_outline,
        tooltip: 'Account',
        onTap: () => showAccountSheet(context),
      );
    }
    return Tooltip(
      message: 'Account',
      child: GestureDetector(
        onTap: () => showAccountSheet(context),
        child: Avatar(initials: app.account?.initials, size: 46),
      ),
    );
  }

  Widget _livePill(bool live, Color ink) {
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: live ? _live : ink.withValues(alpha: 0.45), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(live ? 'Live' : 'No data', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Glass(
      key: ValueKey('loading'),
      radius: 22,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
    );
  }

  Widget _card(TrafficFeed f, bool live, Color color, Color ink, Color muted) {
    final a = latestAdvisory;
    final detail = live ? '${f.vehicles} in frame · ${_pretty(f.level)}' : 'Waiting for the camera';

    return Glass(
      key: const ValueKey('card'),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: AnimatedSize(
        duration: _fade,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Congestion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                AnimatedSwitcher(
                  duration: _fade,
                  child: Text(
                    live ? '${f.score}%' : '–',
                    key: ValueKey(live ? f.score : 'off'),
                    style: TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w300, letterSpacing: -0.8, color: live ? ink : muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: a == null ? null : onOpenLogs,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a == null ? detail : '$detail · Advisory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: live ? color : muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (a != null) Icon(Icons.chevron_right, size: 18, color: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _pretty(String raw) {
  if (raw.isEmpty) return raw;
  final lower = raw.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

class _Tiles {
  const _Tiles(this.url, this.credit, this.maxNativeZoom);

  final String url;
  final String credit;
  final int maxNativeZoom;
}

_Tiles _tilesFor(MapBasemap basemap) {
  return switch (basemap) {
    MapBasemap.osm => const _Tiles(
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        '© OpenStreetMap contributors',
        19,
      ),
    MapBasemap.satellite => const _Tiles(
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        'Tiles © Esri',
        19,
      ),
    MapBasemap.light => const _Tiles(
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
        'Tiles © Esri',
        16,
      ),
  };
}

/// Same blurred-map background in both themes. Only the tint color changes.
class _MapFrost extends StatelessWidget {
  const _MapFrost({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tint = dark ? const Color(0xFF0B0C0F) : Colors.white;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: ui.TileMode.clamp),
        child: ColoredBox(color: tint.withValues(alpha: 0.34)),
      ),
    );
  }
}

/// Blue teardrop used by the desk map for the camera point.
class _LeafletPinPainter extends CustomPainter {
  const _LeafletPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.42;
    final center = Offset(size.width / 2, radius + 1);
    final path = ui.Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..moveTo(center.dx - radius * 0.52, center.dy + radius * 0.62)
      ..lineTo(size.width / 2, size.height - 1)
      ..lineTo(center.dx + radius * 0.52, center.dy + radius * 0.62)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFF2A81CB));
    canvas.drawCircle(center, radius * 0.38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Keeps a finger on this panel from dragging the map underneath it.
class _Hold extends StatelessWidget {
  const _Hold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (_) {},
      onHorizontalDragUpdate: (_) {},
      child: child,
    );
  }
}
