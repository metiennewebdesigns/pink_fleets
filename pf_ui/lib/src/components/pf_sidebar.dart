import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';
import 'pf_nav_items.dart';

/// Full expanded desktop sidebar — 240 px wide by default.
///
/// Shows icon + label in a horizontal row with a highlighted selection state.
///
/// ```dart
/// Row(
///   children: [
///     PFSidebar(
///       selectedIndex: _page,
///       onDestinationSelected: (i) => setState(() => _page = i),
///       items: _navItems,
///       header: _logoHeader,
///       footer: _signOutTile,
///     ),
///     Expanded(child: _pages[_page]),
///   ],
/// )
/// ```
class PFSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<PFNavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  final Widget? footer;
  final double width;

  const PFSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.header,
    this.footer,
    this.width = 240,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, const Divider(height: 1)],
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: PFSpacing.sm,
                vertical: PFSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final selected = i == selectedIndex;
                final iconColor =
                    selected ? PFColors.primary : PFColors.muted;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => onDestinationSelected(i),
                    borderRadius:
                        BorderRadius.circular(PFSpacing.radius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: PFSpacing.md,
                        vertical: PFSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? PFColors.primarySoft
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(PFSpacing.radius),
                      ),
                      child: Row(
                        children: [
                          _resolveIcon(
                            selected
                                ? (item.activeIcon ?? item.icon)
                                : item.icon,
                            iconColor,
                            20,
                          ),
                          const SizedBox(width: PFSpacing.sm),
                          Expanded(
                            child: Text(
                              item.label,
                              style: PFTypography.labelMedium.copyWith(
                                color: selected
                                    ? PFColors.primary
                                    : PFColors.inkSoft,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (footer != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(PFSpacing.base),
              child: footer!,
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
