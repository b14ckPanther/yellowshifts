import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/notifications/domain/models/notification_item.dart';
import 'package:yellowshifts/features/notifications/domain/models/unread_count_summary.dart';
import 'package:yellowshifts/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:yellowshifts/features/notifications/presentation/widgets/notification_badge_icon.dart';
import 'package:yellowshifts/features/notifications/presentation/widgets/notification_tile.dart';

void main() {
  Widget createTestWidget(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('he')],
        home: Scaffold(body: child),
      ),
    );
  }

  group('NotificationTile Widget Tests', () {
    testWidgets(
        'renders schedule publication notification tile with parameters',
        (tester) async {
      final item = NotificationItem(
        id: 'notif-1',
        category: NotificationCategory.schedule,
        eventType: 'SCHEDULE_PUBLISHED',
        priority: NotificationPriority.normal,
        titleKey: 'notif_schedule_published_title',
        bodyKey: 'notif_schedule_published_body',
        renderData: const {
          'week_start_date': '2026-08-30',
          'version': 2,
        },
        actionType: 'NAVIGATE_SCHEDULE',
        actionData: const {},
        isMandatory: false,
        readAt: null,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(createTestWidget(NotificationTile(item: item)));

      expect(find.text('Schedule Published'), findsOneWidget);
      expect(
          find.text(
              'Official work schedule published for week 2026-08-30 (v2).'),
          findsOneWidget);
      expect(find.text('5m ago'), findsOneWidget);
      expect(find.text('Tap to open'), findsOneWidget);
    });

    testWidgets('renders Hebrew localization correctly', (tester) async {
      final item = NotificationItem(
        id: 'notif-2',
        category: NotificationCategory.attendance,
        eventType: 'EMPLOYEE_LATE',
        priority: NotificationPriority.critical,
        titleKey: 'notif_emp_late_title',
        bodyKey: 'notif_emp_late_body',
        renderData: const {
          'employee_name': 'יוסי כהן',
          'shift_name': 'משמרת בוקר',
          'late_minutes': 15,
        },
        actionData: const {},
        isMandatory: false,
        readAt: null,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(createTestWidget(
        NotificationTile(item: item),
        locale: const Locale('he'),
      ));

      expect(find.text('התראת איחור עובד'), findsOneWidget);
      expect(find.text('יוסי כהן מאחר/ת ב-15 דקות למשמרת משמרת בוקר.'),
          findsOneWidget);
      expect(find.text('דחוף'), findsOneWidget);
      expect(find.text('לפני 2 שעות'), findsOneWidget);
    });
  });

  group('NotificationBadgeIcon Widget Tests', () {
    testWidgets('renders clean icon when unread count is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(
              () => _MockUnreadCountNotifier(UnreadCountSummary.zero()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBadgeIcon(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(NotificationBadgeIcon), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders badge counter and pulses on unread notifications',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(
              () => _MockUnreadCountNotifier(
                const UnreadCountSummary(unreadCount: 7, criticalCount: 1),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBadgeIcon(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('7'), findsOneWidget);
    });
  });
}

class _MockUnreadCountNotifier extends UnreadCountNotifier {
  final UnreadCountSummary _summary;
  _MockUnreadCountNotifier(this._summary);

  @override
  Future<UnreadCountSummary> build() async => _summary;
}
