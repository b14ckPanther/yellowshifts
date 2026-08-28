import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yellowshifts/features/reports/presentation/widgets/kpi_summary_card.dart';
import 'package:yellowshifts/features/reports/presentation/widgets/active_session_card.dart';
import 'package:yellowshifts/features/reports/presentation/widgets/history_timeline_tile.dart';
import 'package:yellowshifts/features/reports/domain/models/open_attendance_session.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_history_item.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('KpiSummaryCard Widget Tests', () {
    testWidgets('renders title, value, and badge correctly', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          const KpiSummaryCard(
            title: 'Total Worked Time',
            value: '160h 0m',
            subtitle: '2 stations',
            icon: LucideIcons.clock,
            badgeText: 'On Track',
          ),
        ),
      );

      expect(find.text('Total Worked Time'), findsOneWidget);
      expect(find.text('160h 0m'), findsOneWidget);
      expect(find.text('2 stations'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
    });
  });

  group('ActiveSessionCard Widget Tests', () {
    testWidgets('renders active shift with elapsed duration', (tester) async {
      final session = OpenAttendanceSession(
        id: '1',
        stationId: 'st-1',
        stationName: 'Station North',
        checkInTime: DateTime.now().subtract(const Duration(minutes: 90)),
        shiftNameSnapshot: 'Morning Shift',
        elapsedMinutes: 90,
        needsAttention: false,
      );

      await tester
          .pumpWidget(_wrapWithL10n(ActiveSessionCard(session: session)));

      expect(find.text('ACTIVE SHIFT IN PROGRESS'), findsOneWidget);
      expect(find.text('Station North'), findsOneWidget);
      expect(find.text('Morning Shift'), findsOneWidget);
    });

    testWidgets('renders warning banner when needsAttention is true',
        (tester) async {
      final session = OpenAttendanceSession(
        id: '2',
        stationId: 'st-1',
        stationName: 'Station North',
        checkInTime: DateTime.now().subtract(const Duration(hours: 17)),
        shiftNameSnapshot: 'Long Shift',
        elapsedMinutes: 1020,
        needsAttention: true,
      );

      await tester
          .pumpWidget(_wrapWithL10n(ActiveSessionCard(session: session)));

      expect(find.text('Shift exceeds 16 hours. Review checkout status.'),
          findsOneWidget);
    });
  });

  group('HistoryTimelineTile Widget Tests', () {
    testWidgets('renders completed shift with late badge and duration',
        (tester) async {
      final item = AttendanceHistoryItem(
        id: 'h-1',
        stationId: 'st-1',
        stationName: 'Station North',
        stationCode: 'STA-N',
        shiftNameSnapshot: 'Morning Shift',
        checkInTime: DateTime.parse('2026-08-20T08:15:00.000Z'),
        checkOutTime: DateTime.parse('2026-08-20T16:15:00.000Z'),
        workedMinutes: 480,
        lateMinutes: 15,
        status: 'COMPLETED',
        verificationMethod: 'KIOSK_QR',
        operationalDate: '2026-08-20',
        isLate: true,
        isCorrected: false,
        correctionCount: 0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(_wrapWithL10n(HistoryTimelineTile(item: item)));

      expect(find.text('Morning Shift'), findsOneWidget);
      expect(find.text('Late 15m'), findsOneWidget);
      expect(find.text('8h 0m'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });
  });
}
