import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yellowshifts/core/design_system/components/app_button.dart';
import 'package:yellowshifts/core/design_system/components/app_text_field.dart';
import 'package:yellowshifts/core/design_system/components/app_status_badge.dart';
import 'package:yellowshifts/core/design_system/components/app_avatar.dart';
import 'package:yellowshifts/shared/widgets/app_empty_state.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Design System Widgets', () {
    testWidgets('AppButton renders label and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Clock In',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Clock In'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(tapped, true);
    });

    testWidgets('AppButton displays loading spinner when isLoading = true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Submit',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppTextField renders label and responds to input',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Operator Name',
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Operator Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'David Cohen');
      expect(controller.text, 'David Cohen');
    });

    testWidgets('AppStatusBadge renders status and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStatusBadge(
              label: 'Active',
              variant: AppBadgeVariant.success,
              icon: LucideIcons.check,
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('AppAvatar renders initials correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(name: 'Sarah Levi'),
          ),
        ),
      );

      expect(find.text('SL'), findsOneWidget);
    });

    testWidgets('AppEmptyState renders title, description, and action button',
        (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'No Shifts Found',
              description: 'There are no active shifts scheduled today.',
              actionLabel: 'Create Shift',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Shifts Found'), findsOneWidget);
      expect(find.text('There are no active shifts scheduled today.'),
          findsOneWidget);
      expect(find.text('Create Shift'), findsOneWidget);

      await tester.tap(find.text('Create Shift'));
      expect(actionTapped, true);
    });
  });
}
