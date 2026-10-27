import 'package:flutter/material.dart';

import '../config.dart';
import '../controller.dart';
import '../notice_prefs.dart';
import '../theme.dart';
import 'account_sheet.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final prefs = app.notice;
    final account = app.account;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 96),
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: PageTitle('Settings')),
          const SizedBox(height: 16),

          // Account
          _card(
            p,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => showAccountSheet(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Avatar(initials: account?.initials, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account?.name ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(account?.email ?? 'Sign in or create an account', style: TextStyle(color: p.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: p.muted),
                  ],
                ),
              ),
            ),
          ),

          // Appearance
          _label(p, 'APPEARANCE'),
          _card(
            p,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _caption(p, 'Theme'),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18), label: Text('System')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
                      ],
                      selected: {app.themeMode},
                      onSelectionChanged: (set) => app.setThemeMode(set.first),
                      style: _segmentStyle(p),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      app.themeMode == ThemeMode.system ? 'Following your phone setting.' : 'Overrides your phone setting.',
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _caption(p, 'Panels'),
                  Row(
                    children: [
                      Text('Opaque', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Slider(
                          value: app.glass,
                          onChanged: app.setGlass,
                        ),
                      ),
                      Text('Glass', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Text(
                    app.glass < 0.02 ? 'Solid panels, easiest to read.' : 'Glass. Drag right to see more of the map through the panels.',
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _caption(p, 'Map type'),
                  for (final type in MapBasemap.values)
                    InkWell(
                      onTap: () => app.setBasemap(type),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              app.basemap == type ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 20,
                              color: app.basemap == type ? p.lime : p.muted,
                            ),
                            const SizedBox(width: 10),
                            Text(type.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Notifications
          _label(p, 'NOTIFICATIONS'),
          _card(
            p,
            child: Column(
              children: [
                _switch(
                  p,
                  title: 'Phone alerts',
                  subtitle: 'Show a badge for new advisories',
                  value: prefs.alertsEnabled,
                  onChanged: (value) => app.setNotice(prefs.copyWith(alertsEnabled: value)),
                ),
                for (final level in NoticePrefs.levels) ...[
                  Divider(height: 1, color: p.line, indent: 16, endIndent: 16),
                  _switch(
                    p,
                    title: level,
                    subtitle: 'Include $level advisories',
                    value: prefs.enabledLevels.contains(level),
                    onChanged: prefs.alertsEnabled
                        ? (value) {
                            final next = Set<String>.from(prefs.enabledLevels);
                            if (value) {
                              next.add(level);
                            } else {
                              next.remove(level);
                            }
                            app.setNotice(prefs.copyWith(enabledLevels: next));
                          }
                        : null,
                  ),
                ],
              ],
            ),
          ),

          // About
          _label(p, 'ABOUT'),
          _card(
            p,
            child: Column(
              children: [
                _info(p, 'App version', app.version),
                Divider(height: 1, color: p.line, indent: 16, endIndent: 16),
                _info(p, 'Build', app.build),
                Divider(height: 1, color: p.line, indent: 16, endIndent: 16),
                _info(p, 'Advisory data', AppConfig.useDemoAdvisories ? 'Demo' : 'Live'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(Pal p, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  ButtonStyle _segmentStyle(Pal p) {
    return SegmentedButton.styleFrom(
      foregroundColor: p.ink,
      selectedForegroundColor: p.onSolid,
      selectedBackgroundColor: p.solid,
      side: BorderSide(color: p.line),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
    );
  }

  Widget _label(Pal p, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
      child: Text(text, style: TextStyle(color: p.muted, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w800)),
    );
  }

  Widget _card(Pal p, {required Widget child}) {
    return Material(color: p.card, borderRadius: BorderRadius.circular(22), clipBehavior: Clip.antiAlias, child: child);
  }

  Widget _switch(
    Pal p, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _info(Pal p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          Text(value, style: TextStyle(color: p.muted, fontSize: 14)),
        ],
      ),
    );
  }
}
