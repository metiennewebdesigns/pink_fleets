import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Standard PF modal dialog. Wraps [showDialog] with brand styling.
///
/// ```dart
/// PFModal.show(
///   context: context,
///   title: 'Confirm',
///   body: Text('Are you sure?'),
///   actions: [PFButtonPrimary(label: 'Yes', onPressed: ...)],
/// );
/// ```
class PFModal extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;

  const PFModal({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.contentPadding,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget body,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => PFModal(title: title, body: body, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PFColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radiusXl),
        side: const BorderSide(color: PFColors.border),
      ),
      title: Text(title, style: PFTypography.headlineSmall),
      content: DefaultTextStyle(
        style: PFTypography.bodyMedium,
        child: body,
      ),
      contentPadding: contentPadding ??
          const EdgeInsets.fromLTRB(
            PFSpacing.xl,
            PFSpacing.base,
            PFSpacing.xl,
            PFSpacing.xl,
          ),
      actions: actions != null
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PFSpacing.base,
                  0,
                  PFSpacing.base,
                  PFSpacing.base,
                ),
                child: Wrap(
                  spacing: PFSpacing.sm,
                  runSpacing: PFSpacing.sm,
                  children: actions!,
                ),
              ),
            ]
          : null,
    );
  }
}
