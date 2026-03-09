import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';

/// Presents [child] as a branded modal bottom-sheet.
///
/// ```dart
/// PFBottomSheet.show(context: context, title: 'Options', child: ...);
/// ```
class PFBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (_) => _PFBottomSheetContent(title: title, child: child),
    );
  }
}

class _PFBottomSheetContent extends StatelessWidget {
  final String? title;
  final Widget child;

  const _PFBottomSheetContent({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PFColors.surfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PFSpacing.radiusXl)),
        border: Border(
          top: BorderSide(color: PFColors.border),
          left: BorderSide(color: PFColors.border),
          right: BorderSide(color: PFColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PFSpacing.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: PFColors.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(PFSpacing.radiusFull),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: PFSpacing.base),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PFSpacing.xl),
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: PFColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: PFSpacing.sm),
              const Divider(color: PFColors.border, height: 1),
            ] else
              const SizedBox(height: PFSpacing.sm),
            child,
            const SizedBox(height: PFSpacing.base),
          ],
        ),
      ),
    );
  }
}
