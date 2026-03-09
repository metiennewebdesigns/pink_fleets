import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';
import '../pf_animations.dart';

/// Secondary action button — dark elevated surface, subtle border, scale
/// feedback on press.
///
/// Use for secondary CTAs alongside [PFButtonPrimary].
///
/// ```dart
/// PFSecondaryButton(label: 'Back', icon: Icons.arrow_back, onPressed: _goBack)
/// ```
class PFSecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final Color? foreground;
  final Color? background;

  const PFSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.foreground,
    this.background,
  });

  @override
  State<PFSecondaryButton> createState() => _PFSecondaryButtonState();
}

class _PFSecondaryButtonState extends State<PFSecondaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PFAnimations.fast);
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: PFAnimations.curveInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final fg = widget.foreground ?? PFColors.ink;
    final bg = widget.background ?? PFColors.surfaceHigh;

    Widget content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 17, color: fg),
          const SizedBox(width: PFSpacing.sm),
        ],
        if (!widget.loading)
          Text(
            widget.label,
            style: PFTypography.labelLarge.copyWith(color: fg),
          ),
      ],
    );

    Widget button = Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _ctrl.forward(),
        onTapUp: disabled ? null : (_) => _ctrl.reverse(),
        onTapCancel: () => _ctrl.reverse(),
        onTap: widget.onPressed,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PFSpacing.lg,
              vertical: PFSpacing.md,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(PFSpacing.radius),
              border: Border.all(color: PFColors.border),
            ),
            child: content,
          ),
        ),
      ),
    );

    if (widget.fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
