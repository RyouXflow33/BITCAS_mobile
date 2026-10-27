import 'package:flutter/material.dart';

/// Colour tokens. Light and dark share the same orange accent as the desk
/// (`--orange: #f59e0b`).
class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.lime,
    required this.onLime,
    required this.solid,
    required this.onSolid,
    required this.track,
    required this.night,
  });

  final Color bg;
  final Color card;
  final Color cardAlt;
  final Color ink;
  final Color muted;
  final Color line;
  final Color lime;
  final Color onLime;

  /// Strong fill for selected pills and primary buttons.
  final Color solid;
  final Color onSolid;

  /// Unfilled part of a progress bar.
  final Color track;

  /// 0 in light mode, 1 in dark mode. This fades during a theme change.
  final double night;

  static const light = Pal(
    bg: Color(0xFFE4E4E6),
    card: Color(0xFFF1F1F2),
    cardAlt: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    muted: Color(0xFF6B6B70),
    line: Color(0xFFD9D9DC),
    lime: Color(0xFFF59E0B),
    onLime: Color(0xFF111111),
    solid: Color(0xFF111111),
    onSolid: Color(0xFFFFFFFF),
    track: Color(0xFF111111),
    night: 0,
  );

  /// Same charcoal tokens as the desk dark theme in assets/css/glass.css.
  static const dark = Pal(
    bg: Color(0xFF0B0C0F),
    card: Color(0xFF17191E),
    cardAlt: Color(0xFF111317),
    ink: Color(0xFFF3F4F6),
    muted: Color(0xFF8D929C),
    line: Color(0xFF2C2E34),
    lime: Color(0xFFF59E0B),
    onLime: Color(0xFF111111),
    solid: Color(0xFFF59E0B),
    onSolid: Color(0xFF111111),
    track: Color(0xFF3A3D44),
    night: 1,
  );

  static Pal of(BuildContext context) {
    return Theme.of(context).extension<Pal>() ?? light;
  }

  @override
  Pal copyWith({
    Color? bg,
    Color? card,
    Color? cardAlt,
    Color? ink,
    Color? muted,
    Color? line,
    Color? lime,
    Color? onLime,
    Color? solid,
    Color? onSolid,
    Color? track,
    double? night,
  }) {
    return Pal(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      lime: lime ?? this.lime,
      onLime: onLime ?? this.onLime,
      solid: solid ?? this.solid,
      onSolid: onSolid ?? this.onSolid,
      track: track ?? this.track,
      night: night ?? this.night,
    );
  }

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) {
    if (other is! Pal) return this;
    return Pal(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      lime: Color.lerp(lime, other.lime, t)!,
      onLime: Color.lerp(onLime, other.onLime, t)!,
      solid: Color.lerp(solid, other.solid, t)!,
      onSolid: Color.lerp(onSolid, other.onSolid, t)!,
      track: Color.lerp(track, other.track, t)!,
      night: night + (other.night - night) * t,
    );
  }
}

Color advisoryColor(String level) {
  switch (level) {
    case 'High':
      return const Color(0xFFE5483B);
    case 'Moderate':
      return const Color(0xFFF0A020);
    default:
      return const Color(0xFF2FA866);
  }
}

Color trafficColor(String level) {
  switch (level) {
    case 'HEAVY':
      return const Color(0xFFE5483B);
    case 'MODERATE':
      return const Color(0xFFF0A020);
    default:
      return const Color(0xFF2FA866);
  }
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.lime, brightness: brightness).copyWith(
      primary: p.solid,
      onPrimary: p.onSolid,
      surface: p.card,
      onSurface: p.ink,
    ),
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    dividerColor: p.line,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.onLime : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.lime : p.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.solid,
      contentTextStyle: TextStyle(color: p.onSolid, fontWeight: FontWeight.w600),
    ),
    extensions: [p],
  );
}
