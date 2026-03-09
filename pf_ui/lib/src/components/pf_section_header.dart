import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Section header with optional trailing action widget.
///
/// ```dart
/// PFSectionHeader(title: 'Assigned Trips')
/// PFSectionHeader(title: 'Uploads', trailing: TextButton(...))
/// ```
class PFSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool divider;

  const PFSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: PFTypography.headlineSmall.copyWith(
                    color: PFColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (divider) ...[
          const SizedBox(height: PFSpacing.sm),
          const Divider(color: PFColors.border, height: 1),
        ],
      ],
    );
  }
}
