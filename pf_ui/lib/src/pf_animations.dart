import 'package:flutter/animation.dart';

/// Animation duration + curve constants for the Pink Fleets design system.
class PFAnimations {
  PFAnimations._();

  // Durations
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration verySlow = Duration(milliseconds: 600);

  // Curves (fast-out-slow-in — Apple/Fluent style)
  static const curve = _PFCurves.easeOut;
  static const curveIn = _PFCurves.easeIn;
  static const curveInOut = _PFCurves.easeInOut;
  static const curveSpring = _PFCurves.spring;
  static const curveDecelerate = _PFCurves.decelerate;
}

class _PFCurves {
  static const easeOut = Cubic(0.0, 0.0, 0.2, 1.0);
  static const easeIn = Cubic(0.4, 0.0, 1.0, 1.0);
  static const easeInOut = Cubic(0.4, 0.0, 0.2, 1.0);
  static const spring = Cubic(0.175, 0.885, 0.32, 1.275);
  static const decelerate = Cubic(0.0, 0.0, 0.2, 1.0);
}
