import 'package:flutter/widgets.dart';

/// Semantic spacing tokens for YellowShifts.
abstract class AppSpacing {
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // Radius shortcuts
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusFull = 999.0;

  // Insets
  static const EdgeInsets insetAll4 = EdgeInsets.all(space4);
  static const EdgeInsets insetAll8 = EdgeInsets.all(space8);
  static const EdgeInsets insetAll12 = EdgeInsets.all(space12);
  static const EdgeInsets insetAll16 = EdgeInsets.all(space16);
  static const EdgeInsets insetAll20 = EdgeInsets.all(space20);
  static const EdgeInsets insetAll24 = EdgeInsets.all(space24);
  static const EdgeInsets insetAll32 = EdgeInsets.all(space32);
  static const EdgeInsets insetAll48 = EdgeInsets.all(space48);

  // Inset shortcuts
  static const EdgeInsets inset16 = insetAll16;
  static const EdgeInsets inset24 = insetAll24;

  static const EdgeInsets insetHorizontal16 =
      EdgeInsets.symmetric(horizontal: space16);
  static const EdgeInsets insetHorizontal24 =
      EdgeInsets.symmetric(horizontal: space24);
  static const EdgeInsets insetVertical12 =
      EdgeInsets.symmetric(vertical: space12);
  static const EdgeInsets insetVertical16 =
      EdgeInsets.symmetric(vertical: space16);
}
