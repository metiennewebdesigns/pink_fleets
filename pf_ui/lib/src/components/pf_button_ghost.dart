import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Ghost / outline button — subtle dark border, white text.
class PFButtonGhost extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final Color? foreground;
  final Color? borderColor;

  const PFButtonGhost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.foreground,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? PFColors.ink;
    final bc = borderColor ?? PFColors.border;
    final disabled = onPressed == null;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: PFSpacing.sm),
        ],
        Text(label, style: PFTypography.labelLarge.copyWith(color: fg)),
      ],
    );

    Widget button = Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: bc),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PFSpacing.radius)),
          padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
        ),
        child: content,
      ),
    );

    if (fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
