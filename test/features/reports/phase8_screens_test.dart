import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/design_system/theme/app_theme.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/stations/domain/station.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';
import 'package:yellowshifts/features/stations/presentation/active_station_provider.dart';
import 'package:yellowshifts/features/reports/presentation/screens/export_center_screen.dart';
import 'package:yellowshifts/features/audit/presentation/screens/audit_center_screen.dart';
import 'package:yellowshifts/features/system_health/presentation/screens/system_health_screen.dart';
import 'package:yellowshifts/features/audit/domain/models/audit_log_entry.dart';
import 'package:yellowshifts/features/audit/data/audit_repository.dart';
import 'package:yellowshifts/features/system_health/domain/models/station_system_health.dart';
import 'package:yellowshifts/features/system_health/data/system_health_repository.dart';
import 'package:yellowshifts/features/reports/data/reports_repository.dart';
import 'package:yellowshifts/features/reports/domain/models/report_export_model.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_summary.dart';
import 'package:yellowshifts/features/reports/domain/models/station_attendance_summary.dart';
import 'package:yellowshifts/features/reports/domain/models/daily_attendance_report.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_correction_detail.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

final _testStation = Station(
  id: 'test-station-1',
  name: 'Tel Aviv Station',
  code: 'TLV-01',
  timezone: 'Asia/Jerusalem',
  locale: 'he',
  weekStart: 0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _testAdminMembership = StationMembership(
  id: 'mem-admin',
  stationId: 'test-station-1',
  userId: 'user-admin',
  role: StationRole.admin,
  status: MembershipStatus.active,
  joinedAt: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  station: _testStation,
);

class _MockAuditRepository implements AuditRepository {
  @override
  Future<AuditLogQueryResult> queryAuditLogs({
    required String stationId,
    String? actorId,
    DateTime? from,
    DateTime? to,
    String? actionCategory,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    return AuditLogQueryResult(
      items: [
        AuditLogEntry(
          id: 'log-1',
          stationId: stationId,
          actorId: 'user-admin',
          actorName: 'Admin User',
          actorEmail: 'admin@yellowshifts.com',
          action: 'STATION_SETTINGS_UPDATED',
          targetType: 'STATION',
          targetId: stationId,
          metadata: const {'field': 'timezone', 'value': 'Asia/Jerusalem'},
          createdAt: DateTime(2026, 8, 27, 10, 0),
        ),
      ],
      totalCount: 1,
    );
  }
}

class _MockSystemHealthRepository implements SystemHealthRepository {
  @override
  Future<StationSystemHealth> getStationSystemHealth(String stationId) async {
    return StationSystemHealth(
      stationId: stationId,
      nfcTagsTotal: 3,
      nfcTagsActive: 3,
      exportsTotal24h: 8,
      exportsFailed24h: 0,
      staleOpenSessions: 0,
      serverTime: DateTime(2026, 8, 27, 12, 0),
    );
  }
}

class _MockReportsRepository implements ReportsRepository {
  @override
  Future<AttendanceSummary> getMyAttendanceSummary({
    required DateTime from,
    required DateTime to,
    String? stationId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getMyAttendanceHistory({
    required DateTime from,
    required DateTime to,
    String? stationId,
    String? statusFilter,
    int limit = 25,
    int offset = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<StationAttendanceSummary> getStationAttendanceSummary({
    required String stationId,
    required DateTime from,
    required DateTime to,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getStationEmployeeAttendanceSummary({
    required String stationId,
    required DateTime from,
    required DateTime to,
    String? search,
    String sortBy = 'name',
    String sortOrder = 'asc',
    int limit = 25,
    int offset = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<DailyAttendanceReport> getStationDailyAttendanceReport({
    required String stationId,
    required DateTime date,
  }) =>
      throw UnimplementedError();

  @override
  Future<StationEmployeeAttendanceDetailResponse>
      getStationEmployeeAttendanceDetail({
    required String stationId,
    required String employeeUserId,
    required DateTime from,
    required DateTime to,
  }) =>
          throw UnimplementedError();

  @override
  Future<String> requestExport({
    String? stationId,
    required ReportExportType exportType,
    ExportFormat format = ExportFormat.csv,
    Map<String, dynamic> filterPayload = const {},
  }) async {
    return 'exp-mock-1';
  }

  @override
  Future<ExportGenerationResult> generateExport({
    required String exportId,
  }) async {
    return const ExportGenerationResult(
      exportId: 'exp-mock-1',
      exportType: 'STATION_ATTENDANCE_SUMMARY',
      format: 'CSV',
      success: true,
      downloadUrl: 'https://supabase.co/storage/v1/object/sign/mock.csv',
      rowCount: 15,
      fileSizeBytes: 1024,
    );
  }

  @override
  Future<List<ReportExportItem>> getRecentExports(
      {String? stationId, int limit = 25}) async {
    return [
      ReportExportItem(
        id: 'exp-mock-1',
        stationId: stationId ?? 'test-station-1',
        requestedBy: 'user-admin',
        exportType: ReportExportType.stationAttendanceSummary,
        format: ExportFormat.csv,
        status: ExportStatus.completed,
        storagePath: 'exports/st-1/mock.csv',
        fileSizeBytes: 1024,
        rowCount: 15,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }
}

Widget _wrapScreen(Widget screen) {
  return ProviderScope(
    overrides: [
      activeStationIdProvider.overrideWith(
          (ref) => ActiveStationIdNotifier(null, 'test-station-1')),
      activeMembershipProvider.overrideWith((ref) => _testAdminMembership),
      stationAccessContextProvider.overrideWith((ref) => StationAccessContext(
            isAuthenticated: true,
            hasActiveStation: true,
            activeStationId: 'test-station-1',
            activeMembership: _testAdminMembership,
          )),
      auditRepositoryProvider.overrideWithValue(_MockAuditRepository()),
      systemHealthRepositoryProvider
          .overrideWithValue(_MockSystemHealthRepository()),
      reportsRepositoryProvider.overrideWithValue(_MockReportsRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.buildTheme(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('he')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: screen,
    ),
  );
}

void main() {
  group('Phase 8 Presentation Screens QA', () {
    testWidgets('ExportCenterScreen renders and displays recent exports',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(const ExportCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Operational Export Center'), findsWidgets);
      expect(find.text('Station Attendance Summary'), findsWidgets);
      expect(find.text('Generate Export'), findsOneWidget);
    });

    testWidgets('AuditCenterScreen renders audit log list and category chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(const AuditCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Administrative Audit Center'), findsOneWidget);
      expect(find.text('STATION_SETTINGS_UPDATED'), findsOneWidget);
      expect(find.text('Admin User (admin@yellowshifts.com)'), findsOneWidget);
    });

    testWidgets(
        'SystemHealthScreen renders NFC tag fleet health and data retention controls',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapScreen(const SystemHealthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Station Operational Health'), findsOneWidget);
      expect(find.text('3 of 3 Active'), findsOneWidget);
      expect(find.text('NFC Station Tags'), findsWidgets);
      expect(find.text('Data Lifecycle & Retention'), findsOneWidget);
      expect(find.text('Run Lifecycle Cleanup'), findsOneWidget);
    });
  });
}
