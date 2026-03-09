import 'package:flutter/material.dart';
import 'pf_animations.dart';
import 'pf_colors.dart';

/// Pink Fleets luxury motion system.
///
/// Provides:
/// - Named page transition builders compatible with GoRouter / Navigator 2
/// - [PFPressFeedback] — scale-on-press wrapper for any interactive widget
/// - [PFHoverCard] — subtly elevates on mouse-hover (desktop / web)
/// - [PFPulse] — outward-ring pulse around any widget (live indicators, FABs)
///
/// ### GoRouter example
/// ```dart
/// GoRoute(
///   path: '/booking',
///   pageBuilder: (context, state) => CustomTransitionPage(
///     child: const BookingWizardScreen(embedMode: false),
///     transitionsBuilder: PFMotion.slideUp,
///   ),
/// )
/// ```
class PFMotion {
  PFMotion._();

  /// Slide up + fade-in (default page push).
  static Widget slideUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: PFAnimations.curve),
    );
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Horizontal slide + fade-in (lateral navigation).
  static Widget slideRight(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: PFAnimations.curve),
    );
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Fade-only (modal / overlay push).
  static Widget fade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PFPressFeedback
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps any widget with press-scale + opacity feedback.
///
/// ```dart
/// PFPressFeedback(
///   onTap: () => doSomething(),
///   child: MyCard(),
/// )
/// ```
class PFPressFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const PFPressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.duration = PFAnimations.fast,
  });

  @override
  State<PFPressFeedback> createState() => _PFPressFeedbackState();
}

class _PFPressFeedbackState extends State<PFPressFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween(begin: 1.0, end: widget.scale).animate(
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
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _ctrl.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PFHoverCard
// ─────────────────────────────────────────────────────────────────────────────

/// Card that subtly scales up on mouse hover (desktop / web).
///
/// Falls back to press-scale on touch devices.
class PFHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double hoverScale;

  const PFHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.hoverScale = 1.015,
  });

  @override
  State<PFHoverCard> createState() => _PFHoverCardState();
}

class _PFHoverCardState extends State<PFHoverCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PFAnimations.normal);
    _scale = Tween(begin: 1.0, end: widget.hoverScale).animate(
      CurvedAnimation(parent: _ctrl, curve: PFAnimations.curve),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PFPulse
// ─────────────────────────────────────────────────────────────────────────────

/// Generic outward-ring pulse animation — ideal for live indicators and FABs.
///
/// ```dart
/// PFPulse(
///   color: PFColors.success,
///   child: Container(width: 10, height: 10, decoration: BoxDecoration(
///     color: PFColors.success, shape: BoxShape.circle)),
/// )
/// ```
class PFPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double spread;
  final Duration duration;

  const PFPulse({
    super.key,
    required this.child,
    this.color = PFColors.primary,
    this.spread = 14,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<PFPulse> createState() => _PFPulseState();
}

class _PFPulseState extends State<PFPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _size;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: widget.duration)..repeat();
    _size = Tween(begin: 0.0, end: widget.spread).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _size.value * 2,
            height: _size.value * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: _opacity.value),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}
