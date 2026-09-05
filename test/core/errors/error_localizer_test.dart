import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yellowshifts/core/errors/app_failure.dart';
import 'package:yellowshifts/core/errors/error_localizer.dart';
import 'package:yellowshifts/l10n/app_localizations_en.dart';
import 'package:yellowshifts/l10n/app_localizations_he.dart';

void main() {
  final l10nEn = AppLocalizationsEn();
  final l10nHe = AppLocalizationsHe();

  group('ErrorLocalizer Unit Tests - English', () {
    test('Translates 42501 permission denied', () {
      const err = PostgrestException(message: 'Access denied', code: '42501');
      expect(
          ErrorLocalizer.localize(err, l10nEn), l10nEn.errorPermissionDenied);
    });

    test('Translates P0001 last admin required', () {
      const err = PostgrestException(
        message: 'Cannot revoke the last active administrator',
        code: 'P0001',
      );
      expect(
          ErrorLocalizer.localize(err, l10nEn), l10nEn.errorLastAdminRequired);
    });

    test('Translates P0081 export expired', () {
      const err = PostgrestException(message: 'Export expired', code: 'P0081');
      expect(ErrorLocalizer.localize(err, l10nEn), l10nEn.errorExportExpired);
    });

    test('Translates 42901 rate limit', () {
      const err =
          PostgrestException(message: 'Too many requests', code: '42901');
      expect(ErrorLocalizer.localize(err, l10nEn), l10nEn.errorRateLimited);
    });

    test('Translates NetworkFailure', () {
      const failure = NetworkFailure('Connection lost');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorOfflineActionBlocked);
    });

    test('Translates VersionConflictFailure', () {
      const failure = VersionConflictFailure('Version conflict');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorVersionConflict);
    });

    test('Translates StationDeactivatedFailure', () {
      const failure = StationDeactivatedFailure('Station inactive');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorStationDeactivated);
    });

    test('Translates P00105 station-admin role forbidden', () {
      const err = PostgrestException(
        message: 'Only platform administrators may grant',
        code: 'P00105',
      );
      expect(ErrorLocalizer.localize(err, l10nEn),
          l10nEn.errorStationAdminRoleForbidden);
    });

    test('Translates NotPlatformAdminFailure', () {
      const failure = NotPlatformAdminFailure('denied');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorNotPlatformAdmin);
    });

    test('Translates StationCodeConflictFailure', () {
      const failure = StationCodeConflictFailure('duplicate');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorStationCodeConflict);
    });

    test('Translates MembershipDeactivatedFailure', () {
      const failure = MembershipDeactivatedFailure('Membership suspended');
      expect(ErrorLocalizer.localize(failure, l10nEn),
          l10nEn.errorMembershipDeactivated);
    });

    test('Translates AuthException invalid login credentials to English', () {
      const authErr =
          AuthException('Invalid login credentials', statusCode: '400');
      expect(ErrorLocalizer.localize(authErr, l10nEn),
          l10nEn.loginErrorInvalidCredentials);
    });

    test('Translates minified web AuthFailure string cleanly', () {
      const minifiedErr = 'minified:WG: Invalid login credentials (code: 400)';
      expect(ErrorLocalizer.localize(minifiedErr, l10nEn),
          l10nEn.loginErrorInvalidCredentials);
    });
  });

  group('ErrorLocalizer Unit Tests - Hebrew RTL', () {
    test('Translates 42501 permission denied to Hebrew', () {
      const err = PostgrestException(message: 'Access denied', code: '42501');
      expect(
          ErrorLocalizer.localize(err, l10nHe), l10nHe.errorPermissionDenied);
      expect(ErrorLocalizer.localize(err, l10nHe), contains('אין לך הרשאות'));
    });

    test('Translates VersionConflictFailure to Hebrew', () {
      const failure = VersionConflictFailure('Version conflict');
      expect(ErrorLocalizer.localize(failure, l10nHe),
          l10nHe.errorVersionConflict);
    });

    test('Translates AuthException invalid login credentials to Hebrew', () {
      const authErr =
          AuthException('Invalid login credentials', statusCode: '400');
      expect(ErrorLocalizer.localize(authErr, l10nHe),
          l10nHe.loginErrorInvalidCredentials);
      expect(ErrorLocalizer.localize(authErr, l10nHe),
          contains('אימייל או סיסמה שגויים'));
    });
  });
}
