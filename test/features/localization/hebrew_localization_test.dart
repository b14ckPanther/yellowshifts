import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/errors/app_failure.dart';
import 'package:yellowshifts/core/errors/error_localizer.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

void main() {
  group('Hebrew Localization & ErrorLocalizer Tests', () {
    testWidgets('AppLocalizations loads Hebrew strings with full key parity',
        (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('he'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      // Verify Hebrew Role Translations
      expect(l10n.roleAdmin, equals('מנהל תחנה'));
      expect(l10n.roleShiftManager, equals('מנהל משמרת'));
      expect(l10n.roleEmployee, equals('עובד'));
      expect(l10n.rolePlatformAdmin, equals('מנהל פלטפורמה'));
      expect(l10n.platformAdminTitle, equals('ניהול הפלטפורמה'));
      expect(l10n.platformAdminMode, equals('מצב פלטפורמה'));

      // Verify Hebrew Status Translations
      expect(l10n.statusActive, equals('פעיל'));
      expect(l10n.statusInactive, equals('לא פעיל'));
      expect(l10n.statusSuspended, equals('מושעה'));

      // Verify Navigation
      expect(l10n.navDashboard, equals('לוח בקרה'));
      expect(l10n.navSchedule, equals('סידור עבודה'));
      expect(l10n.navMyHours, equals('השעות שלי'));
      expect(l10n.navEmployees, equals('עובדים'));
      expect(l10n.navSettings, equals('הגדרות'));

      // Verify Dashboard Sections
      expect(l10n.navSectionWorkspace, equals('סביבת עבודה אישית'));
      expect(l10n.navSectionManagement, equals('ניהול תחנה'));
      expect(l10n.dashboardStationOverview, equals('מבט על התחנה'));

      // Verify Error Message Localizations
      expect(
        ErrorLocalizer.localize(
          const DatabaseFailure('Cannot remove admin', code: 'P0001'),
          l10n,
        ),
        equals('לא ניתן להסיר או להשבית את מנהל התחנה הפעיל האחרון.'),
      );

      expect(
        ErrorLocalizer.localize(
          const DatabaseFailure('Duplicate phone error', code: '23505'),
          l10n,
        ),
        equals('מספר טלפון זה כבר מקושר למשתמש אחר במערכת.'),
      );

      expect(
        ErrorLocalizer.localize(
          const DatabaseFailure('Access denied', code: '42501'),
          l10n,
        ),
        equals('הגישה נדחתה. אין לך הרשאות מתאימות לפעולה זו.'),
      );
    });

    testWidgets('AppLocalizations loads English strings correctly',
        (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.roleAdmin, equals('Administrator'));
      expect(l10n.roleShiftManager, equals('Shift Manager'));
      expect(l10n.roleEmployee, equals('Employee'));
      expect(l10n.statusActive, equals('Active'));

      expect(
        ErrorLocalizer.localize(
          const DatabaseFailure('Cannot remove admin', code: 'P0001'),
          l10n,
        ),
        equals(
            'Cannot demote or deactivate the last active Administrator of this station.'),
      );
    });
  });
}
