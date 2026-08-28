import 'package:flutter/widgets.dart';

/// Semantic motion durations and curves for YellowShifts.
abstract class AppMotion {
  // Durations
  static const Duration durationInstant = Duration.zero;
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationStandard = Duration(milliseconds: 250);
  static const Duration durationExpressive = Duration(milliseconds: 400);

  // Curves
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.easeOutQuart;
  static const Curve curveDecelerate = Curves.easeOut;
  static const Curve curveSpring = Curves.elasticOut;
}
