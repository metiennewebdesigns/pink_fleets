import 'package:flutter/material.dart';
import '../pf_colors.dart';
import 'pf_nav_items.dart';

/// Mobile bottom navigation bar following the PF dark design system.
///
/// ```dart
/// PFBottomNav(
///   currentIndex: _tab,
///   onTap: (i) => setState(() => _tab = i),
///   items: const [
///     PFNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
///     PFNavItem(icon: Icons.history_outlined, label: 'Trips'),
///   ],
/// )
/// ```
class PFBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<PFNavItem> items;
  final ValueChanged<int> onTap;

  const PFBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PFColors.surface,
        border: Border(top: BorderSide(color: PFColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;
              final iconWidget = _resolveIcon(
                selected ? (item.activeIcon ?? item.icon) : item.icon,
                selected ? PFColors.primary : PFColors.muted,
                22,
              );

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected ? PFColors.primary : PFColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  static Widget _resolveIcon(dynamic icon, Color color, double size) {
    if (icon is IconData) {
      return Icon(icon, size: size, color: color);
    }
    if (icon is Widget) return icon;
    return const SizedBox.shrink();
  }
}
