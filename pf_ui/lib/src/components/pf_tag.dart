import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Small label pill — use for metadata, categories, file types.
class PFTag extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  const PFTag({
    super.key,
    required this.label,
    this.color,
    this.background,
    this.icon,
  });

  /// A pink brand tag.
  factory PFTag.primary(String label) =>
      PFTag(label: label, color: PFColors.primary, background: PFColors.primarySoft);

  /// A gold highlight tag.
  factory PFTag.gold(String label) =>
      PFTag(label: label, color: PFColors.gold, background: PFColors.goldSoft);

  /// A subtle/muted tag.
  factory PFTag.muted(String label) =>
      PFTag(label: label, color: PFColors.muted, background: PFColors.surface);

  @override
  Widget build(BuildContext context) {
    final fg = color ?? PFColors.inkSoft;
    final bg = background ?? PFColors.surfaceHigh;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PFSpacing.sm + 2, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PFSpacing.radiusFull),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: PFTypography.labelSmall.copyWith(color: fg, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
