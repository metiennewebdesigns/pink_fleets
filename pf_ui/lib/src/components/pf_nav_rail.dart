import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import 'pf_nav_items.dart';

/// Tablet navigation rail — 108 px wide icon+label column.
///
/// Drop-in alternative to Flutter's [NavigationRail], fully styled with PF tokens.
///
/// ```dart
/// Row(
///   children: [
///     PFNavRail(
///       selectedIndex: _page,
///       onDestinationSelected: (i) => setState(() => _page = i),
///       items: _navItems,
///       header: _logoWidget,
///       trailing: _signOutButton,
///     ),
///     Expanded(child: _pages[_page]),
///   ],
/// )
/// ```
class PFNavRail extends StatelessWidget {
  final int selectedIndex;
  final List<PFNavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  final Widget? trailing;
  final double width;

  const PFNavRail({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.header,
    this.trailing,
    this.width = 108,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: PFColors.surface,
        border: Border(right: BorderSide(color: PFColors.border)),
      ),
      child: Column(
        children: [
          if (header != null) ...[header!, const Divider(height: 1)],
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: PFSpacing.sm),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final selected = i == selectedIndex;
                final iconColor =
                    selected ? PFColors.primary : PFColors.muted;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PFSpacing.sm,
                    vertical: PFSpacing.xs,
                  ),
                  child: Tooltip(
                    message: item.tooltip ?? item.label,
                    child: InkWell(
                      onTap: () => onDestinationSelected(i),
                      borderRadius:
                          BorderRadius.circular(PFSpacing.radius),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: PFSpacing.sm,
                          vertical: PFSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? PFColors.primarySoft
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(PFSpacing.radius),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _resolveIcon(
                              selected
                                  ? (item.activeIcon ?? item.icon)
                                  : item.icon,
                              iconColor,
                              22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: iconColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (trailing != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PFSpacing.sm),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _resolveIcon(dynamic icon, Color color, double size) {
    if (icon is IconData) return Icon(icon, size: size, color: color);
    if (icon is Widget) return icon;
    return const SizedBox.shrink();
  }
}
