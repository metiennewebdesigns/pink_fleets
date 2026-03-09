import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';

/// Standard dark surface card with optional gradient accent border.
///
/// ```dart
/// PFCard(
///   child: Text('Hello'),
/// )
/// ```
class PFCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Border? border;
  final double? radius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const PFCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border,
    this.radius,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? PFSpacing.radiusMd;
    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(PFSpacing.base),
      decoration: BoxDecoration(
        color: color ?? PFColors.surface,
        borderRadius: BorderRadius.circular(r),
        border: border ?? Border.all(color: PFColors.border),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(r),
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

/// Card with a pink/gold gradient top-border highlight.
class PFAccentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? accentGradient;

  const PFAccentCard({
    super.key,
    required this.child,
    this.padding,
    this.accentGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: accentGradient ?? PFColors.pinkGradient,
        borderRadius: BorderRadius.circular(PFSpacing.radiusMd + 1.5),
      ),
      child: Container(
        padding: padding ?? const EdgeInsets.all(PFSpacing.base),
        decoration: BoxDecoration(
          color: PFColors.surface,
          borderRadius: BorderRadius.circular(PFSpacing.radiusMd),
        ),
        child: child,
      ),
    );
  }
}
