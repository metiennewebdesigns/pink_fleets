import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';

/// Shimmer loading skeleton — mimics content layout while data loads.
class PFSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const PFSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = PFSpacing.radiusSm,
  });

  /// Multi-line text skeleton.
  static Widget lines({int count = 3, double spacing = 8}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? spacing : 0),
          child: PFSkeleton(
            height: 14,
            width: i == count - 1 ? 160 : double.infinity,
          ),
        ),
      ),
    );
  }

  /// Card-shaped skeleton.
  static Widget card({double height = 96}) {
    return PFSkeleton(height: height, radius: PFSpacing.radiusMd);
  }

  @override
  State<PFSkeleton> createState() => _PFSkeletonState();
}

class _PFSkeletonState extends State<PFSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: PFColors.border.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
