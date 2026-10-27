import 'dart:ui' show ColorFilter, ImageFilter, TileMode;

import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';

/// A panel that floats over the map. Solid with a shadow when the driver picks
/// "Opaque", or frosted glass when they pick "Translucent" (Settings).
///
/// Matches the desk map glass in assets/css/glass.css: white at 46% in light
/// mode, charcoal at 38% in dark mode, with a 22px blur.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 24, this.padding});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final night = p.night;
    final shape = BorderRadius.circular(radius);

    final amount = app.glass.clamp(0.0, 1.0);
    if (amount < 0.02) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: shape,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: child,
      );
    }

    // Same see-through amount in light and dark. Only the tint color changes.
    const seeThrough = 0.36;
    final fillAlpha = seeThrough + (0.88 - seeThrough) * (1 - amount);
    final fill = Color.lerp(Colors.white, const Color(0xFF0C0E12), night)!.withValues(alpha: fillAlpha);
    final sigma = 16 + 8 * amount;
    final edge = Color.lerp(const Color(0x1A0F172A), Colors.white.withValues(alpha: 0.12), night)!;
    final onGlass = Color.lerp(const Color(0xFF0F172A), const Color(0xFFF3F4F6), night)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06 + 0.10 * night),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: ColorFilter.matrix(_saturation(1.35)),
            inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: shape,
              border: Border.all(color: edge),
            ),
            child: IconTheme(
              data: IconThemeData(color: onGlass),
              child: DefaultTextStyle(
                style: TextStyle(color: onGlass, fontSize: 14),
                child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button, the main control shape in the design.
class RoundBtn extends StatelessWidget {
  const RoundBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.filled = false,
    this.bg,
    this.fg,
    this.dot = false,
    this.glass = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool filled;
  final Color? bg;
  final Color? fg;

  /// Small lime dot, used to say "something is ready here".
  final bool dot;

  /// Use the [Glass] look. Only for buttons that sit on the map.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final solidFill = bg ?? (filled ? p.solid : null);
    final ink = fg ?? (filled ? p.onSolid : p.ink);
    final tap = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.46, color: ink),
      ),
    );

    Widget button;
    if (glass && solidFill == null) {
      button = Glass(
        radius: size / 2,
        child: Material(type: MaterialType.transparency, child: tap),
      );
    } else {
      button = Material(
        color: solidFill ?? p.cardAlt,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: tap,
      );
    }
    if (dot) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: p.lime,
                shape: BoxShape.circle,
                border: Border.all(color: p.ink, width: 2),
              ),
            ),
          ),
        ],
      );
    }
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Thin progress bar: lime fill on a dark track, as in the mission list.
class MissionBar extends StatelessWidget {
  const MissionBar({super.key, required this.value, this.height = 5, this.fill, this.track});

  final double value;
  final double height;
  final Color? fill;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = value.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(height: height, color: track ?? p.track),
              Container(height: height, width: constraints.maxWidth * v, color: fill ?? p.lime),
            ],
          ),
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class PointsChip extends StatelessWidget {
  const PointsChip(this.points, {super.key});

  final int points;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: p.lime, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 16, color: p.onLime),
          const SizedBox(width: 4),
          Text('$points pts', style: TextStyle(color: p.onLime, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Floating bottom bar. Every tab always shows its icon and its name, and a
/// highlight slides to the tab you are on.
class NavPill extends StatelessWidget {
  const NavPill({super.key, required this.index, required this.onSelect, required this.advisoryBadge});

  final int index;
  final ValueChanged<int> onSelect;
  final int advisoryBadge;

  static const _items = [
    _NavItem(Icons.map_outlined, Icons.map, 'Map'),
    _NavItem(Icons.campaign_outlined, Icons.campaign, 'Advisories'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final night = p.night;
    // Desk tab bar: a light glass chip on the selected item, muted text on the rest.
    final selectedBg = Color.lerp(Colors.white.withValues(alpha: 0.82), Colors.white.withValues(alpha: 0.14), night)!;
    final selectedFg = Color.lerp(const Color(0xFF0F172A), const Color(0xFFF3F4F6), night)!;
    final idle = p.muted;
    return Glass(
      radius: 32,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 52,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutCubic,
              alignment: Alignment((index - 1).toDouble(), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / _items.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: selectedBg, borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      label: _items[i].label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: i == index ? selectedFg : idle),
                          duration: const Duration(milliseconds: 220),
                          builder: (context, color, _) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Badge(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  textColor: Colors.white,
                                  isLabelVisible: i == 1 && advisoryBadge > 0,
                                  label: Text('$advisoryBadge'),
                                  child: Icon(i == index ? _items[i].activeIcon : _items[i].icon, size: 20, color: color),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _items[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: color, fontWeight: i == index ? FontWeight.w600 : FontWeight.w500, fontSize: 11),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// CSS `saturate(1.35)`, applied with the map glass blur.
List<double> _saturation(double amount) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final inv = 1 - amount;
  final r = inv * lumR;
  final g = inv * lumG;
  final b = inv * lumB;
  return <double>[
    r + amount, g, b, 0, 0, //
    r, g + amount, b, 0, 0,
    r, g, b + amount, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Clock time of a capture, such as 1:06 PM.
String clockTime(String iso) {
  final time = DateTime.tryParse(iso)?.toLocal();
  if (time == null) return iso;
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String clockDate(String iso) {
  final time = DateTime.tryParse(iso)?.toLocal();
  if (time == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[time.month - 1]} ${time.day}';
}

String timeAgo(String iso) {
  final time = DateTime.tryParse(iso)?.toLocal();
  if (time == null) return iso;
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
