import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Status indicator chip — pill-shaped, coloured by semantic status.
///
/// ```dart
/// PFChipStatus(status: 'in_progress')
/// PFChipStatus(status: 'completed', label: 'Done')
/// ```
class PFChipStatus extends StatelessWidget {
  final String status;
  final String? label;
  final bool dot;

  const PFChipStatus({
    super.key,
    required this.status,
    this.label,
    this.dot = true,
  });

  static _ChipStyle _styleFor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'accepted':
      case 'driver_assigned':
      case 'confirmed':
        return _ChipStyle(PFColors.primary, PFColors.primarySoft, 'Accepted');
      case 'en_route':
        return _ChipStyle(PFColors.warning, PFColors.warningSoft, 'En Route');
      case 'arrived':
        return _ChipStyle(PFColors.info, PFColors.infoSoft, 'Arrived');
      case 'in_progress':
        return _ChipStyle(PFColors.success, PFColors.successSoft, 'In Progress');
      case 'completed':
        return _ChipStyle(PFColors.muted, PFColors.surface, 'Completed');
      case 'cancelled':
        return _ChipStyle(PFColors.danger, PFColors.dangerSoft, 'Cancelled');
      case 'pending':
        return _ChipStyle(PFColors.gold, PFColors.goldSoft, 'Pending');
      case 'draft':
        return _ChipStyle(PFColors.muted, PFColors.surface, 'Draft');
      case 'submitted':
        return _ChipStyle(PFColors.success, PFColors.successSoft, 'Submitted');
      case 'online':
        return _ChipStyle(PFColors.success, PFColors.successSoft, 'Online');
      case 'offline':
        return _ChipStyle(PFColors.muted, PFColors.surface, 'Offline');
      default:
        return _ChipStyle(PFColors.muted, PFColors.surface, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(status);
    final displayLabel = label ?? s.defaultLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PFSpacing.md, vertical: PFSpacing.xs + 2),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(PFSpacing.radiusFull),
        border: Border.all(color: s.fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: s.fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: PFSpacing.xs),
          ],
          Text(
            displayLabel,
            style: PFTypography.labelSmall.copyWith(
              color: s.fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipStyle {
  final Color fg;
  final Color bg;
  final String defaultLabel;
  const _ChipStyle(this.fg, this.bg, this.defaultLabel);
}
