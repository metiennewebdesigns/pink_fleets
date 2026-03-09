import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';
import '../pf_animations.dart';

/// Primary action button — pink gradient with tap-scale animation.
class PFButtonPrimary extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final Color? backgroundColor;
  final Gradient? gradient;

  const PFButtonPrimary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.backgroundColor,
    this.gradient,
  });

  @override
  State<PFButtonPrimary> createState() => _PFButtonPrimaryState();
}

class _PFButtonPrimaryState extends State<PFButtonPrimary>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PFAnimations.fast);
    _scale = Tween(begin: 1.0, end: 0.96).animate(
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
    Widget content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(PFColors.white),
            ),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: PFColors.white),
          const SizedBox(width: PFSpacing.sm),
        ],
        if (!widget.loading)
          Text(widget.label, style: PFTypography.labelLarge.copyWith(color: PFColors.white)),
      ],
    );

    final gradient = widget.gradient ?? PFColors.pinkGradient;
    final bg = widget.backgroundColor;

    Widget button = Opacity(
      opacity: disabled ? 0.45 : 1.0,
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
              gradient: bg == null ? gradient : null,
              color: bg,
              borderRadius: BorderRadius.circular(PFSpacing.radius),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: PFColors.primaryGlow,
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
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

/// Gold gradient primary button — used for premium CTAs.
class PFGoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PFGoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PFButtonPrimary(
      label: label,
      onPressed: onPressed,
      icon: icon,
      gradient: PFColors.goldGradient,
    );
  }
}
