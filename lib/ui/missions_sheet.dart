import 'package:flutter/material.dart';

import '../controller.dart';
import '../missions.dart';
import '../theme.dart';
import 'account_sheet.dart';
import 'widgets.dart';

Future<void> showMissionsSheet(BuildContext context, {MissionKind kind = MissionKind.daily}) {
  if (AppScope.of(context).isGuest) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestLock(),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MissionsSheet(initial: kind),
  );
}

class _GuestLock extends StatelessWidget {
  const _GuestLock();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(22, 12, 22, 22 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const Text('Missions', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Sign in to open missions and claim rewards. Guest mode can still use the map.',
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.lime,
                foregroundColor: p.onLime,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                showAccountSheet(navigator.context);
              },
              child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class MissionsSheet extends StatefulWidget {
  const MissionsSheet({super.key, required this.initial});

  final MissionKind initial;

  @override
  State<MissionsSheet> createState() => _MissionsSheetState();
}

class _MissionsSheetState extends State<MissionsSheet> {
  late MissionKind _kind = widget.initial;
  String? _detailId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final media = MediaQuery.of(context);
    final detail = _detailId == null ? null : missionById[_detailId];

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.84),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + media.padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (detail == null) ..._listView(context, app, p) else ..._detailView(context, app, p, detail),
          ],
        ),
      ),
    );
  }

  // ---- list ----

  List<Widget> _listView(BuildContext context, AppController app, Pal p) {
    final missions = app.missionsOf(_kind);
    return [
      PageTitle('Mission', trailing: PointsChip(app.board.points)),
      const SizedBox(height: 14),
      _tabs(app, p),
      const SizedBox(height: 8),
      for (var i = 0; i < missions.length; i++) ...[
        _row(app, p, missions[i]),
        if (i < missions.length - 1) Divider(height: 1, color: p.line),
      ],
      const SizedBox(height: 14),
      if (_kind == MissionKind.daily)
        _note(p, Icons.local_fire_department_outlined,
            app.streak > 0 ? '${app.streak}-day streak. Claim a daily mission each day to keep it.' : 'Claim a daily mission to start a streak.')
      else
        Row(
          children: [
            Expanded(
              child: Text(
                app.board.rerolled ? 'New random missions arrive tomorrow.' : 'Random missions change every day.',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: app.board.rerolled ? null : app.rerollRandom,
              icon: const Icon(Icons.shuffle, size: 18),
              label: const Text('Shuffle once'),
              style: TextButton.styleFrom(foregroundColor: p.ink),
            ),
          ],
        ),
    ];
  }

  Widget _note(Pal p, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: p.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: p.muted, fontSize: 12))),
      ],
    );
  }

  Widget _tabs(AppController app, Pal p) {
    Widget tab(MissionKind kind, IconData icon, String label) {
      final selected = _kind == kind;
      final ready = app.claimableCount(kind) > 0;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _kind = kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            decoration: BoxDecoration(
              color: selected ? p.solid : Colors.transparent,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? p.onSolid : p.ink),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? p.onSolid : p.ink)),
                if (ready) ...[
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: p.lime, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.cardAlt, borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          tab(MissionKind.daily, Icons.event_available_outlined, 'Daily'),
          tab(MissionKind.random, Icons.casino_outlined, 'Random'),
        ],
      ),
    );
  }

  Widget _row(AppController app, Pal p, MissionDef m) {
    final value = app.progressOf(m.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(child: MissionBar(value: value / m.target)),
                    const SizedBox(width: 10),
                    Text(m.progressLabel(value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _statusButton(app, p, m),
          const SizedBox(width: 8),
          RoundBtn(
            icon: Icons.chevron_right,
            filled: true,
            size: 40,
            tooltip: 'Details',
            onTap: () => setState(() => _detailId = m.id),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(AppController app, Pal p, MissionDef m) {
    if (app.isClaimed(m.id)) {
      return RoundBtn(icon: Icons.check, size: 40, bg: p.cardAlt, fg: p.muted, onTap: null, tooltip: 'Claimed');
    }
    if (app.canClaim(m.id)) {
      return RoundBtn(
        icon: Icons.redeem,
        size: 40,
        bg: p.lime,
        fg: p.onLime,
        tooltip: 'Claim ${m.reward} pts',
        onTap: () => app.claim(m.id),
      );
    }
    return RoundBtn(icon: Icons.flag_outlined, size: 40, onTap: () => setState(() => _detailId = m.id), tooltip: 'In progress');
  }

  // ---- detail ----

  List<Widget> _detailView(BuildContext context, AppController app, Pal p, MissionDef m) {
    final value = app.progressOf(m.id);
    final claimed = app.isClaimed(m.id);
    final canClaim = app.canClaim(m.id);

    Widget kv(String label, Widget child) {
      return Column(
        children: [
          Divider(height: 1, color: p.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 84, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      );
    }

    return [
      Row(
        children: [
          Expanded(child: Text(m.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.2))),
          const SizedBox(width: 12),
          RoundBtn(icon: Icons.chevron_left, filled: true, tooltip: 'Back', onTap: () => setState(() => _detailId = null)),
        ],
      ),
      const SizedBox(height: 16),
      kv('Category', Text(m.kind == MissionKind.daily ? 'Daily' : 'Random', textAlign: TextAlign.end, style: TextStyle(color: p.muted, fontSize: 13))),
      kv(
        'Progress',
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(m.progressLabel(value), style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 7),
            MissionBar(value: value / m.target),
          ],
        ),
      ),
      kv('Hint', Text(m.hint, style: TextStyle(color: p.muted, fontSize: 13, height: 1.3))),
      kv(
        'Reward',
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: p.lime, shape: BoxShape.circle),
              child: Icon(Icons.bolt, color: p.onLime, size: 22),
            ),
            const SizedBox(width: 10),
            Text('BITCAS Points x ${m.reward}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: canClaim ? p.lime : p.solid,
            foregroundColor: canClaim ? p.onLime : p.onSolid,
            disabledBackgroundColor: p.cardAlt,
            disabledForegroundColor: p.muted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: claimed ? null : (canClaim ? () => app.claim(m.id) : () => Navigator.of(context).pop()),
          icon: Icon(claimed ? Icons.check : (canClaim ? Icons.redeem : Icons.map_outlined)),
          label: Text(
            claimed ? 'Reward claimed' : (canClaim ? 'Claim reward' : 'Keep going'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ];
  }
}
