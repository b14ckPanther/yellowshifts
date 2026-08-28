import 'package:flutter/material.dart';

/// Locale-aware typography system for YellowShifts.
/// English uses Ubuntu, Hebrew uses Heebo.
class AppTypography {
  final String localeCode;

  const AppTypography({this.localeCode = 'he'});

  bool get isHebrew => localeCode.startsWith('he');

  TextStyle _baseTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color color = const Color(0xFF000000),
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: isHebrew ? 'Heebo' : 'Ubuntu',
      fontFamilyFallback: const [
        'Heebo',
        'Ubuntu',
        'Roboto',
        'Arial',
        'sans-serif'
      ],
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  TextStyle get displayLarge => _baseTextStyle(
        fontSize: 32.0,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  TextStyle get titleLarge => _baseTextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  TextStyle get titleMedium => _baseTextStyle(
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  TextStyle get bodyLarge => _baseTextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  TextStyle get bodyMedium => _baseTextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  TextStyle get bodyStrong => _baseTextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  TextStyle get labelLarge => _baseTextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  TextStyle get titleSmall => _baseTextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  TextStyle get bodySmall => _baseTextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        height: 1.35,
      );

  TextStyle get labelSmall => _baseTextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  TextStyle get caption => _baseTextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: const Color(0xFF8E8E93),
      );

  TextStyle get headlineMedium => _baseTextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  TextStyle get headlineSmall => _baseTextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  TextStyle get numericLarge => _baseTextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.5,
      );

  TextStyle get numericCompact => _baseTextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );
}
