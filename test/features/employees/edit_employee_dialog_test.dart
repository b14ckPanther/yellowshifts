import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/employees/domain/employee_details.dart';
import 'package:yellowshifts/features/employees/presentation/widgets/edit_employee_dialog.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

void main() {
  final testEmployee = EmployeeDetails(
    membershipId: 'mem-123',
    stationId: 'st-456',
    userId: 'usr-789',
    role: StationRole.employee,
    status: MembershipStatus.active,
    employeeCode: 'EMP-999',
    joinedAt: DateTime(2026, 1, 15),
    firstName: 'David',
    lastName: 'Cohen',
    phone: '+972501234567',
    preferredLocale: 'he',
    email: 'david.cohen@test.com',
  );

  Widget createTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: EditEmployeeDialog(employee: testEmployee),
        ),
      ),
    );
  }

  group('EditEmployeeDialog UI Tests', () {
    testWidgets('Populates fields with existing employee data', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('David'), findsOneWidget);
      expect(find.text('Cohen'), findsOneWidget);
      expect(find.text('+972501234567'), findsOneWidget);
      expect(find.text('david.cohen@test.com'), findsOneWidget);
      expect(find.text('EMP-999'), findsOneWidget);
      expect(find.text('Edit Employee Profile'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Validates required first and last name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Clear first name
      await tester.enterText(find.widgetWithText(TextFormField, 'David'), '');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please verify the entered details.'), findsOneWidget);
    });
  });
}
