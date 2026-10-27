import 'package:flutter/material.dart';

import '../config.dart';
import '../controller.dart';
import '../feed.dart';
import '../missions.dart';
import '../theme.dart';
import 'widgets.dart';

class AdvisoriesScreen extends StatelessWidget {
  const AdvisoriesScreen({super.key, required this.advisories, required this.error});

  final List<Advisory> advisories;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final prefs = app.notice;
    final visible = advisories.where((item) => prefs.enabledLevels.contains(item.level)).toList();

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: PageTitle(
                  'Advisory log',
                  trailing: AppConfig.useDemoAdvisories ? StatusPill('DEMO DATA', p.muted) : null,
                ),
              ),
              if (!prefs.alertsEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text('Phone alerts are off. Turn them on in Settings when you want a notice.', style: TextStyle(color: p.muted, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              Expanded(child: _list(context, p, visible, prefs.alertsEnabled)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, Pal p, List<Advisory> visible, bool alertsOn) {
    if (error != null && advisories.isEmpty) {
      return Center(child: Text(error!, style: TextStyle(color: p.muted)));
    }
    if (advisories.isEmpty) {
      return Center(child: Text('No advisories yet.', style: TextStyle(color: p.muted)));
    }
    if (visible.isEmpty) {
      return Center(child: Text('No advisories for the levels selected in Settings.', style: TextStyle(color: p.muted)));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 96),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = visible[index];
        final color = advisoryColor(item.level);
        final captured = clockTime(item.sentAtIso);
        return Glass(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(context, item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 52,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: alertsOn ? color : p.muted, borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusPill(item.level.toUpperCase(), color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.streetLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, height: 1.3)),
                      const SizedBox(height: 8),
                      Text('$captured · ${item.roadLabel}', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Advisory item) {
    AppScope.of(context).record(MissionEvent.advisoryOpen);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final p = Pal.of(sheetContext);
        final color = advisoryColor(item.level);
        final captured = clockTime(item.sentAtIso);
        final when = clockDate(item.sentAtIso);
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(sheetContext).padding.bottom),
          child: Glass(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Row(
                  children: [
                    StatusPill(item.level.toUpperCase(), color),
                    const Spacer(),
                    Text(item.channel, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(captured, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: -0.6, height: 1)),
                const SizedBox(height: 4),
                Text('Captured · $when · ${timeAgo(item.sentAtIso)}', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _place(p, Icons.signpost_outlined, 'Street', item.streetLabel),
                const SizedBox(height: 10),
                _place(p, Icons.alt_route, 'Road', item.roadLabel),
                const SizedBox(height: 14),
                Text(item.message, style: const TextStyle(fontSize: 15, height: 1.4)),
                if (AppConfig.useDemoAdvisories) ...[
                  const SizedBox(height: 14),
                  Text('This is a sample advisory shown while the live feed is not connected.', style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _place(Pal p, IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 18, color: p.lime),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}
