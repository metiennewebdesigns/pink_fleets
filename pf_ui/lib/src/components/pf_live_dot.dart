import 'package:flutter/material.dart';
import '../pf_colors.dart';

/// A small animated status dot that pulses / blinks to indicate liveness.
///
/// ```dart
/// PFLiveDot(status: 'online')   // green pulse
/// PFLiveDot(status: 'arrived')  // amber static
/// PFLiveDot(status: 'offline')  // red static
/// ```
///
/// Status strings map:
/// - `online`, `en_route`, `in_progress`  → [PFColors.success] (green)
/// - `arrived`, `pending`, `idle`          → [PFColors.warning] (amber)
/// - `offline`, `cancelled`                → [PFColors.danger]  (red)
/// - anything else                          → [PFColors.muted]  (grey)
class PFLiveDot extends StatefulWidget {
  final String status;

  /// Diameter of the dot in logical pixels. Defaults to 10.
  final double size;

  /// Whether to animate. Set to false for static display (e.g. in lists).
  final bool animate;

  const PFLiveDot({
    super.key,
    required this.status,
    this.size = 10,
    this.animate = true,
  });

  @override
  State<PFLiveDot> createState() => _PFLiveDotState();
}

class _PFLiveDotState extends State<PFLiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  Color _resolveColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'online':
      case 'en_route':
      case 'in_progress':
        return PFColors.success;
      case 'arrived':
      case 'pending':
      case 'idle':
        return PFColors.warning;
      case 'offline':
      case 'cancelled':
        return PFColors.danger;
      default:
        return PFColors.muted;
    }
  }

  bool get _shouldAnimate {
    final s = widget.status.toLowerCase().replaceAll(' ', '_');
    return widget.animate &&
        (s == 'online' || s == 'en_route' || s == 'in_progress');
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (_shouldAnimate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PFLiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(widget.status);

    if (!_shouldAnimate) {
      return _dot(color, widget.size, 1.0, 1.0);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Opacity(
            opacity: (1.0 - _opacity.value).clamp(0.0, 0.4),
            child: Container(
              width: widget.size * _scale.value,
              height: widget.size * _scale.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Core dot
          _dot(color, widget.size, _opacity.value, 1.0),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size, double opacity, double scale) =>
      Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: size * 0.8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
}
