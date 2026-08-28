import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yellowshifts/core/design_system/tokens/app_colors.dart';
import 'package:yellowshifts/core/design_system/tokens/app_radius.dart';
import 'package:yellowshifts/core/design_system/tokens/app_spacing.dart';
import 'package:yellowshifts/core/design_system/motion/app_motion.dart';
import 'package:yellowshifts/core/design_system/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Design System Tokens', () {
    test('AppColors strictly maps brand palette values', () {
      expect(AppColors.colorSurfaceBrand, const Color(0xFFFCBC00));
      expect(AppColors.colorSurfaceBrandAccent, const Color(0xFFFFDB07));
      expect(AppColors.colorTextBrand, const Color(0xFFD10040));
      expect(AppColors.colorSurfaceBase, const Color(0xFFF6F6F6));
      expect(AppColors.colorSurfaceRaised, const Color(0xFFFFFFFF));
      expect(AppColors.colorTextPrimary, const Color(0xFF000000));
    });

    test('AppSpacing provides consistent incremental scales', () {
      expect(AppSpacing.space4, 4.0);
      expect(AppSpacing.space8, 8.0);
      expect(AppSpacing.space16, 16.0);
      expect(AppSpacing.space24, 24.0);
      expect(AppSpacing.space32, 32.0);
    });

    test('AppRadius provides geometric border radius scale', () {
      expect(AppRadius.radiusSm, 8.0);
      expect(AppRadius.radiusMd, 12.0);
      expect(AppRadius.radiusLg, 16.0);
      expect(AppRadius.radiusPill, 999.0);
    });

    test('AppMotion provides standard durations and curves', () {
      expect(AppMotion.durationFast, const Duration(milliseconds: 150));
      expect(AppMotion.durationStandard, const Duration(milliseconds: 250));
      expect(AppMotion.durationExpressive, const Duration(milliseconds: 400));
    });

    test('AppTheme generates ThemeData with correct primary tokens', () {
      final themeHe = AppTheme.buildTheme(localeCode: 'he');
      expect(themeHe.scaffoldBackgroundColor, AppColors.colorSurfaceBase);
      expect(themeHe.primaryColor, AppColors.colorActionPrimary);

      final themeEn = AppTheme.buildTheme(localeCode: 'en');
      expect(themeEn.scaffoldBackgroundColor, AppColors.colorSurfaceBase);
      expect(themeEn.primaryColor, AppColors.colorActionPrimary);
    });
  });
}
