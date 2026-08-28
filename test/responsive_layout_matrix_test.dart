import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yellowshifts/app/routing/shell/adaptive_app_shell.dart';
import 'package:yellowshifts/app/routing/shell/compact_app_shell.dart';
import 'package:yellowshifts/app/routing/shell/expanded_app_shell.dart';
import 'package:yellowshifts/app/routing/shell/medium_app_shell.dart';
import 'package:yellowshifts/core/auth/auth_state_provider.dart';
import 'package:yellowshifts/shared/models/user_profile.dart';
import 'package:yellowshifts/core/design_system/theme/app_theme.dart';
import 'package:yellowshifts/features/authentication/presentation/login_screen.dart';
import 'package:yellowshifts/features/dashboard/presentation/dashboard_screen.dart';
import 'package:yellowshifts/features/employees/data/employee_repository.dart';
import 'package:yellowshifts/features/employees/domain/employee_details.dart';
import 'package:yellowshifts/features/employees/presentation/employees_screen.dart';
import 'package:yellowshifts/features/settings/presentation/settings_screen.dart';
import 'package:yellowshifts/features/settings/presentation/station_settings_screen.dart';
import 'package:yellowshifts/features/settings/presentation/shift_manager_permissions_screen.dart';
import 'package:yellowshifts/features/shift_templates/data/shift_template_repository.dart';
import 'package:yellowshifts/features/shift_templates/domain/shift_template.dart';
import 'package:yellowshifts/features/shift_templates/presentation/shift_templates_screen.dart';
import 'package:yellowshifts/features/permissions/data/permissions_repository.dart';
import 'package:yellowshifts/features/permissions/domain/shift_manager_permissions.dart';
import 'package:yellowshifts/features/availability/data/availability_repository.dart';
import 'package:yellowshifts/features/availability/domain/availability_period.dart';
import 'package:yellowshifts/features/availability/domain/availability_submission.dart';
import 'package:yellowshifts/features/availability/domain/availability_matrix.dart';
import 'package:yellowshifts/features/availability/presentation/employee_availability_screen.dart';
import 'package:yellowshifts/features/availability/presentation/manager_availability_screen.dart';
import 'package:yellowshifts/features/availability/presentation/availability_history_screen.dart';
import 'package:yellowshifts/features/stations/data/station_repository.dart';
import 'package:yellowshifts/features/stations/domain/station.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';
import 'package:yellowshifts/features/stations/presentation/active_station_provider.dart';
import 'package:yellowshifts/features/stations/presentation/station_selector_screen.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/notifications/domain/models/unread_count_summary.dart';
import 'package:yellowshifts/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

import 'package:yellowshifts/shared/widgets/app_empty_state.dart';
import 'package:yellowshifts/shared/widgets/app_error_state.dart';

final _testStation = Station(
  id: 'test-station-1',
  name: 'Tel Aviv Central Station',
  code: 'TLV-01',
  timezone: 'Asia/Jerusalem',
  locale: 'he',
  weekStart: 0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _testMembership = StationMembership(
  id: 'mem-1',
  stationId: 'test-station-1',
  userId: 'user-1',
  role: StationRole.admin,
  status: MembershipStatus.active,
  joinedAt: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  station: _testStation,
);

final _testProfile = UserProfile(
  id: 'user-1',
  firstName: 'David',
  lastName: 'Cohen',
  phone: '0501234567',
  preferredLocale: 'he',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _testEmployeeList = [
  EmployeeDetails(
    membershipId: 'mem-1',
    stationId: 'test-station-1',
    userId: 'user-1',
    role: StationRole.admin,
    status: MembershipStatus.active,
    employeeCode: 'ADM-001',
    joinedAt: DateTime(2026, 1, 1),
    firstName: 'David',
    lastName: 'Cohen',
    phone: '0501234567',
  ),
  EmployeeDetails(
    membershipId: 'mem-2',
    stationId: 'test-station-1',
    userId: 'user-2',
    role: StationRole.shiftManager,
    status: MembershipStatus.active,
    employeeCode: 'MGR-002',
    joinedAt: DateTime(2026, 1, 1),
    firstName: 'Sarah',
    lastName: 'Levi',
    phone: '0529876543',
  ),
];

final _testTemplates = [
  ShiftTemplate(
    id: 'st-1',
    stationId: 'test-station-1',
    name: 'Morning',
    code: 'MOR',
    startTime: const TimeOfDay(hour: 7, minute: 0),
    endTime: const TimeOfDay(hour: 15, minute: 30),
    sortOrder: 0,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  ShiftTemplate(
    id: 'st-2',
    stationId: 'test-station-1',
    name: 'Evening',
    code: 'EVE',
    startTime: const TimeOfDay(hour: 15, minute: 30),
    endTime: const TimeOfDay(hour: 23, minute: 0),
    sortOrder: 1,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  ShiftTemplate(
    id: 'st-3',
    stationId: 'test-station-1',
    name: 'Night',
    code: 'NIGHT',
    startTime: const TimeOfDay(hour: 23, minute: 0),
    endTime: const TimeOfDay(hour: 7, minute: 0),
    sortOrder: 2,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
];

const _testSnapshotTemplates = [
  PeriodShiftTemplateSnapshot(
    id: 'st-1',
    name: 'Morning',
    code: 'MOR',
    startTime: TimeOfDay(hour: 7, minute: 0),
    endTime: TimeOfDay(hour: 15, minute: 30),
    sortOrder: 0,
  ),
  PeriodShiftTemplateSnapshot(
    id: 'st-2',
    name: 'Evening',
    code: 'EVE',
    startTime: TimeOfDay(hour: 15, minute: 30),
    endTime: TimeOfDay(hour: 23, minute: 0),
    sortOrder: 1,
  ),
];

final _testPeriod = AvailabilityPeriod(
  id: 'period-1',
  stationId: 'test-station-1',
  weekStartDate: DateTime(2026, 9, 6),
  status: AvailabilityPeriodStatus.open,
  submissionDeadline: DateTime(2026, 9, 5, 18, 0),
  templates: _testSnapshotTemplates,
);

const _testMatrix = AvailabilityMatrix(
  periodId: 'period-1',
  stationId: 'test-station-1',
  metrics: AvailabilityKpiMetrics(
    eligibleEmployees: 2,
    submittedEmployees: 1,
    draftEmployees: 1,
    notStartedEmployees: 0,
    notSubmittedEmployees: 1,
  ),
  templates: _testSnapshotTemplates,
  members: [
    AvailabilityMatrixMember(
      membershipId: 'mem-1',
      userId: 'user-1',
      firstName: 'David',
      lastName: 'Cohen',
      role: 'ADMIN',
      employeeCode: 'ADM-001',
      submissionStatus: AvailabilitySubmissionStatus.submitted,
      entries: {'2026-09-06_st-1': true, '2026-09-06_st-2': true},
    ),
    AvailabilityMatrixMember(
      membershipId: 'mem-2',
      userId: 'user-2',
      firstName: 'Sarah',
      lastName: 'Levi',
      role: 'SHIFT_MANAGER',
      employeeCode: 'MGR-002',
      submissionStatus: AvailabilitySubmissionStatus.draft,
      entries: {'2026-09-06_st-1': true},
    ),
  ],
);

class _MockTestEmployeeRepository implements EmployeeRepository {
  @override
  Future<List<EmployeeDetails>> getStationEmployees({
    required String stationId,
    String? search,
    StationRole? role,
    MembershipStatus? status,
  }) async =>
      _testEmployeeList;

  @override
  Future<Map<String, dynamic>> createEmployee({
    required String stationId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required StationRole role,
    String? employeeCode,
  }) async =>
      {};

  @override
  Future<Map<String, dynamic>> updateEmployeeProfile({
    required String stationId,
    required String userId,
    required String membershipId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? preferredLocale,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async =>
      {'success': true};

  @override
  Future<void> updateMembership({
    required String stationId,
    required String membershipId,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async {}

  @override
  Future<String> resetEmployeePassword({
    required String stationId,
    required String userId,
  }) async =>
      'Ys#Temp123';

  @override
  Future<void> revokeEmployeeSessions({
    required String stationId,
    required String userId,
  }) async {}
}

class _MockTestStationRepository implements StationRepository {
  @override
  Future<Station?> getStationById(String stationId) async => _testStation;

  @override
  Future<List<Station>> getUserStations() async => [_testStation];

  @override
  Future<void> updateStation(Station station,
      {bool forceDeactivate = false, String? deactivationReason}) async {}

  @override
  Future<Map<String, dynamic>> getStationPulse(String stationId) async => {
        'total_active_members': 2,
        'admin_count': 1,
        'shift_manager_count': 1,
        'employee_count': 0,
      };
}

class _MockTestShiftTemplateRepository implements ShiftTemplateRepository {
  @override
  Future<List<ShiftTemplate>> getStationTemplates(String stationId,
          {bool activeOnly = false}) async =>
      _testTemplates;

  @override
  Future<ShiftTemplate> createTemplate({
    required String stationId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
  }) async =>
      _testTemplates.first;

  @override
  Future<ShiftTemplate> updateTemplate({
    required String stationId,
    required String templateId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
    bool isActive = true,
  }) async =>
      _testTemplates.first;

  @override
  Future<void> reorderTemplates(
      String stationId, List<String> templateIds) async {}

  @override
  Future<void> deactivateTemplate(String stationId, String templateId) async {}

  @override
  Future<void> reactivateTemplate(String stationId, String templateId) async {}
}

class _MockTestPermissionsRepository implements PermissionsRepository {
  @override
  Future<ShiftManagerPermissions> getShiftManagerPermissions(
          String stationId) async =>
      const ShiftManagerPermissions();

  @override
  Future<void> updateShiftManagerPermissions(
      String stationId, ShiftManagerPermissions permissions) async {}
}

class _MockTestAvailabilityRepository implements AvailabilityRepository {
  @override
  Future<AvailabilityPeriod?> getCurrentAvailabilityPeriod(
          String stationId) async =>
      _testPeriod;

  @override
  Future<List<AvailabilityPeriod>> listAvailabilityPeriods(
          String stationId) async =>
      [_testPeriod];

  @override
  Future<AvailabilityPeriod> getAvailabilityPeriod(String periodId) async =>
      _testPeriod;

  @override
  Future<String> createAvailabilityPeriod({
    required String stationId,
    required DateTime weekStartDate,
    required DateTime submissionDeadline,
    String? notes,
  }) async =>
      'period-1';

  @override
  Future<void> openAvailabilityPeriod(String periodId) async {}

  @override
  Future<void> closeAvailabilityPeriod(String periodId) async {}

  @override
  Future<void> reopenAvailabilityPeriod(
      String periodId, DateTime newDeadline) async {}

  @override
  Future<EmployeeAvailabilitySubmission?> getMySubmission(
          String periodId) async =>
      EmployeeAvailabilitySubmission(
        periodId: 'period-1',
        stationId: 'test-station-1',
        weekStartDate: DateTime(2026, 9, 6),
        periodStatus: 'OPEN',
        submissionDeadline: DateTime(2026, 9, 5, 18, 0),
        submissionStatus: AvailabilitySubmissionStatus.draft,
        entries: const {'2026-09-06_st-1': true},
      );

  @override
  Future<void> saveDraft(
      {required String periodId,
      required List<Map<String, dynamic>> entries}) async {}

  @override
  Future<void> submitAvailability(
      {required String periodId,
      required List<Map<String, dynamic>> entries}) async {}

  @override
  Future<AvailabilityMatrix> getAvailabilityMatrix({
    required String periodId,
    String? search,
    String? statusFilter,
    String? roleFilter,
  }) async =>
      _testMatrix;
}

class _MockUnreadCountNotifier extends UnreadCountNotifier {
  @override
  Future<UnreadCountSummary> build() async {
    return UnreadCountSummary.zero();
  }
}

Widget _createTestRouterWidget({required Widget screen}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => screen,
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      activeStationIdProvider.overrideWith(
          (ref) => ActiveStationIdNotifier(null, 'test-station-1')),
      activeMembershipProvider.overrideWith((ref) => _testMembership),
      stationAccessContextProvider.overrideWith((ref) => StationAccessContext(
            isAuthenticated: true,
            hasActiveStation: true,
            activeStationId: 'test-station-1',
            activeMembership: _testMembership,
          )),
      unreadNotificationCountProvider
          .overrideWith(() => _MockUnreadCountNotifier()),
      userMembershipsStreamProvider
          .overrideWith((ref) => Stream.value([_testMembership])),
      currentProfileProvider.overrideWith((ref) async => _testProfile),
      stationRepositoryProvider.overrideWithValue(_MockTestStationRepository()),
      employeeRepositoryProvider
          .overrideWithValue(_MockTestEmployeeRepository()),
      shiftTemplateRepositoryProvider
          .overrideWithValue(_MockTestShiftTemplateRepository()),
      permissionsRepositoryProvider
          .overrideWithValue(_MockTestPermissionsRepository()),
      availabilityRepositoryProvider
          .overrideWithValue(_MockTestAvailabilityRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.buildTheme(),
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  const widths = [
    320.0,
    375.0,
    414.0,
    600.0,
    768.0,
    820.0,
    1024.0,
    1440.0,
    1600.0,
  ];

  group('Responsive Layout Matrix QA (320px to 1600px)', () {
    for (final width in widths) {
      testWidgets('LoginScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester
            .pumpWidget(_createTestRouterWidget(screen: const LoginScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'LoginScreen had overflow at ${width}px');
      });

      testWidgets(
          'StationSelectorScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const StationSelectorScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'StationSelectorScreen had overflow at ${width}px');
      });

      testWidgets('DashboardScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const DashboardScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'DashboardScreen had overflow at ${width}px');
      });

      testWidgets('EmployeesScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const EmployeesScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'EmployeesScreen had overflow at ${width}px');
      });

      testWidgets(
          'StationSettingsScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const StationSettingsScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'StationSettingsScreen had overflow at ${width}px');
      });

      testWidgets('SettingsScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const SettingsScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'SettingsScreen had overflow at ${width}px');
      });

      testWidgets('ShiftTemplatesScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const ShiftTemplatesScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'ShiftTemplatesScreen had overflow at ${width}px');
      });

      testWidgets(
          'ShiftManagerPermissionsScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_createTestRouterWidget(
            screen: const ShiftManagerPermissionsScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'ShiftManagerPermissionsScreen had overflow at ${width}px');
      });

      testWidgets(
          'EmployeeAvailabilityScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_createTestRouterWidget(
            screen: const EmployeeAvailabilityScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'EmployeeAvailabilityScreen had overflow at ${width}px');
      });

      testWidgets(
          'ManagerAvailabilityScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const ManagerAvailabilityScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'ManagerAvailabilityScreen had overflow at ${width}px');
      });

      testWidgets(
          'AvailabilityHistoryScreen renders without overflow at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            _createTestRouterWidget(screen: const AvailabilityHistoryScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'AvailabilityHistoryScreen had overflow at ${width}px');
      });

      testWidgets('Empty and Error states render cleanly at ${width}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_createTestRouterWidget(
          screen: const Column(
            children: [
              Expanded(
                  child: AppEmptyState(
                      title: 'Empty Test', description: 'Description')),
              Expanded(
                  child: AppErrorState(
                      title: 'Error Test', description: 'Test description')),
            ],
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Empty/Error states had overflow at ${width}px');
      });
    }

    testWidgets('AdaptiveAppShell renders Compact shell for width < 600px',
        (tester) async {
      tester.view.physicalSize = const Size(400.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_createTestRouterWidget(
        screen: const AdaptiveAppShell(child: Text('Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CompactAppShell), findsOneWidget);
    });

    testWidgets(
        'AdaptiveAppShell renders Medium shell for width 600px - 1024px',
        (tester) async {
      tester.view.physicalSize = const Size(768.0, 1024.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_createTestRouterWidget(
        screen: const AdaptiveAppShell(child: Text('Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(MediumAppShell), findsOneWidget);
    });

    testWidgets('AdaptiveAppShell renders Expanded shell for width > 1024px',
        (tester) async {
      tester.view.physicalSize = const Size(1280.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_createTestRouterWidget(
        screen: const AdaptiveAppShell(child: Text('Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ExpandedAppShell), findsOneWidget);
    });
  });
}
