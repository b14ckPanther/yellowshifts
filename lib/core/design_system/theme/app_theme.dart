import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Centralized ThemeData factory for YellowShifts.
class AppTheme {
  static ThemeData buildTheme({String localeCode = 'he'}) {
    final typography = AppTypography(localeCode: localeCode);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.colorActionPrimary,
      scaffoldBackgroundColor: AppColors.colorSurfaceBase,
      canvasColor: AppColors.colorSurfaceRaised,
      cardColor: AppColors.colorSurfaceRaised,
      dividerColor: AppColors.colorBorderSubtle,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.colorActionPrimary,
        onPrimary: AppColors.colorTextInverse,
        secondary: AppColors.colorSurfaceBrand,
        onSecondary: AppColors.colorTextPrimary,
        error: AppColors.colorStatusDanger,
        onError: AppColors.colorTextInverse,
        surface: AppColors.colorSurfaceRaised,
        onSurface: AppColors.colorTextPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: typography.displayLarge,
        titleLarge: typography.titleLarge,
        titleMedium: typography.titleMedium,
        bodyLarge: typography.bodyLarge,
        bodyMedium: typography.bodyMedium,
        labelLarge: typography.labelLarge,
        bodySmall: typography.caption,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.colorSurfaceRaised,
        foregroundColor: AppColors.colorTextPrimary,
        centerTitle: false,
        titleTextStyle: typography.titleMedium.copyWith(
          color: AppColors.colorTextPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.colorSurfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: BorderSide(color: AppColors.colorBorderSubtle, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.colorSurfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space16,
        ),
        hintStyle: typography.bodyMedium.copyWith(
          color: AppColors.colorTextMuted,
        ),
        labelStyle: typography.bodyMedium.copyWith(
          color: AppColors.colorTextSecondary,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.colorBorderSubtle),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.colorBorderSubtle),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide:
              BorderSide(color: AppColors.colorActionPrimary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.colorStatusDanger),
        ),
      ),
    );
  }
}
