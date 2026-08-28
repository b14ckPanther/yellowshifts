import 'package:flutter/widgets.dart';

/// Semantic border radius tokens for YellowShifts.
abstract class AppRadius {
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  // Convenience aliases
  static const double radiusSmall = radiusSm;
  static const double radiusMedium = radiusMd;
  static const double radiusLarge = radiusLg;
  static const double radiusFull = radiusPill;

  static const BorderRadius borderXs =
      BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius borderSm =
      BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderMd =
      BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderLg =
      BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderXl =
      BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderPill =
      BorderRadius.all(Radius.circular(radiusPill));
}
