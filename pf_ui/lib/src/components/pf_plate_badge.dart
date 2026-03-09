import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';

/// A styled license-plate badge.
///
/// Renders the [plate] text in a dark monospace container with a gold border,
/// mimicking the look of a real UK/SA-style plate.
///
/// ```dart
/// PFPlateBadge(plate: 'CA 456-789')
/// PFPlateBadge(plate: 'GP 12-34 AB', width: 160)
/// ```
class PFPlateBadge extends StatelessWidget {
  final String plate;

  /// Optional fixed width. Defaults to sizing around the text.
  final double? width;

  /// Font size. Defaults to 12.
  final double fontSize;

  const PFPlateBadge({
    super.key,
    required this.plate,
    this.width,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: PFSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(PFSpacing.radiusSm),
        border: Border.all(
          color: PFColors.gold.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: PFColors.gold.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        plate.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: PFColors.goldLight,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}
