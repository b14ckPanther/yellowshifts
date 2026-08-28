import 'package:flutter/material.dart';

/// Semantic color tokens for YellowShifts.
/// Derived from official brand identity with strict semantic naming.
abstract class AppColors {
  // Brand Surfaces
  static const Color colorSurfaceBrand = Color(0xFFFCBC00);
  static const Color colorSurfaceBrandAccent = Color(0xFFFFDB07);
  static const Color colorSurfaceBrandSubtle = Color(0xFFFFF7CC);

  // App Surfaces
  static const Color colorSurfaceBase = Color(0xFFF6F6F6);
  static const Color colorSurfaceRaised = Color(0xFFFFFFFF);
  static const Color colorSurfaceMuted = Color(0xFFEFEFEF);
  static const Color colorSurfaceOverlay = Color(0x99000000);

  // Text Colors
  static const Color colorTextPrimary = Color(0xFF000000);
  static const Color colorTextSecondary = Color(0xFF555555);
  static const Color colorTextMuted = Color(0xFF8E8E93);
  static const Color colorTextInverse = Color(0xFFFFFFFF);
  static const Color colorTextBrand = Color(0xFFD10040);

  // Borders
  static const Color colorBorderSubtle = Color(0xFFE5E5EA);
  static const Color colorBorderMedium = Color(0xFFD1D1D6);
  static const Color colorBorderStrong = Color(0xFF8E8E93);
  static const Color colorBorderBrand = Color(0xFFD10040);

  // Interactive Actions
  static const Color colorActionPrimary = Color(0xFFD10040);
  static const Color colorActionPrimaryHover = Color(0xFFB00036);
  static const Color colorActionPrimaryActive = Color(0xFF8F002B);
  static const Color colorActionSecondary = Color(0xFF000000);
  static const Color colorActionDestructive = Color(0xFFD10040);

  // Status Indicators
  static const Color colorStatusSuccess = Color(0xFF34C759);
  static const Color colorStatusSuccessSubtle = Color(0xFFE8F9ED);
  static const Color colorStatusWarning = Color(0xFFFF9500);
  static const Color colorStatusWarningSubtle = Color(0xFFFFF4E5);
  static const Color colorStatusDanger = Color(0xFFD10040);
  static const Color colorStatusDangerSubtle = Color(0xFFFFEBEF);
  static const Color colorStatusInfo = Color(0xFF007AFF);
  static const Color colorStatusInfoSubtle = Color(0xFFEBF5FF);

  // Semantic & Brand Aliases
  static const Color colorBrandYellow = colorSurfaceBrand;
  static const Color colorBrandCrimson = colorActionDestructive;
  static const Color colorSurfaceSubtle = colorSurfaceMuted;
  static const Color colorSuccess = colorStatusSuccess;
  static const Color colorWarning = colorStatusWarning;
  static const Color colorError = colorStatusDanger;
  static const Color colorInfo = colorStatusInfo;
}
