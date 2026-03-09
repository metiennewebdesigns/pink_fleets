import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Empty state placeholder — icon + heading + optional body + optional action.
class PFEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const PFEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PFSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PFColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: PFColors.border),
              ),
              child: Icon(icon, size: 32, color: PFColors.muted),
            ),
            const SizedBox(height: PFSpacing.base),
            Text(
              title,
              style: PFTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: PFSpacing.sm),
              Text(
                body!,
                style: PFTypography.bodyMedium.copyWith(color: PFColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: PFSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
