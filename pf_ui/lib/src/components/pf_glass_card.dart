import 'dart:ui';
import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';

/// Luxury frosted-glass card — 20 px radius, BackdropFilter blur, subtle
/// gradient overlay with a gold-tinted top edge border.
///
/// Place on top of a dark gradient background for the full glassmorphism look.
class PFGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurRadius;
  final Color? tint;
  final double? radius;
  final Border? border;

  /// When [elevated] is true a faint glow shadow is added beneath the card.
  final bool elevated;

  const PFGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blurRadius = 24.0,
    this.tint,
    this.radius,
    this.border,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? PFSpacing.radiusCard; // 20 px

    final boxShadows = elevated
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: PFColors.primary.withValues(alpha: 0.06),
              blurRadius: 60,
              offset: const Offset(0, 8),
            ),
          ]
        : <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: boxShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(PFSpacing.md),
            decoration: BoxDecoration(
              // Dark card base + faint white glass overlay
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PFColors.surface.withValues(alpha: 0.92),
                  PFColors.surfaceHigh.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(r),
              border: border ??
                  Border.all(
                    color: PFColors.borderStrong.withValues(alpha: 0.55),
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
