import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yellowshifts/app/routing/shell/platform_admin_shell.dart';
import 'package:yellowshifts/core/design_system/components/app_button.dart';
import 'package:yellowshifts/core/errors/app_failure.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/employees/domain/employee_details.dart';
import 'package:yellowshifts/features/employees/presentation/widgets/edit_employee_dialog.dart';
import 'package:yellowshifts/features/employees/presentation/widgets/employee_detail_inspector.dart';
import 'package:yellowshifts/features/platform_admin/data/platform_admin_repository.dart';
import 'package:yellowshifts/features/platform_admin/domain/platform_audit_entry.dart';
import 'package:yellowshifts/features/platform_admin/domain/platform_overview.dart';
import 'package:yellowshifts/features/platform_admin/domain/platform_station_manager.dart';
import 'package:yellowshifts/features/platform_admin/domain/platform_station_summary.dart';
import 'package:yellowshifts/features/platform_admin/domain/station_create_result.dart';
import 'package:yellowshifts/features/platform_admin/presentation/screens/platform_create_station_screen.dart';
import 'package:yellowshifts/features/platform_admin/presentation/screens/platform_overview_screen.dart';
import 'package:yellowshifts/features/platform_admin/presentation/screens/platform_station_managers_screen.dart';
import 'package:yellowshifts/features/platform_admin/presentation/screens/platform_stations_screen.dart';
import 'package:yellowshifts/features/platform_admin/presentation/widgets/platform_scope_banner.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;
import 'package:yellowshifts/core/auth/auth_repository.dart';
import 'package:yellowshifts/shared/models/user_profile.dart';

final _now = DateTime(2026, 8, 1);

final _kurdani = PlatformStationSummary(
  id: 'sta-kurdani',
  name: 'Kurdani',
  code: 'KRD-01',
  timezone: 'Asia/Jerusalem',
  locale: 'he',
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
  activeMembers: 12,
  adminCount: 1,
  shiftManagerCount: 2,
  employeeCount: 9,
  nfcTagsTotal: 2,
  nfcTagsActive: 1,
  staleOpenSessions: 0,
  exportsFailed24h: 0,
);

final _inactive = PlatformStationSummary(
  id: 'sta-inactive',
  name: 'Haifa North',
  code: 'HFA-01',
  timezone: 'Asia/Jerusalem',
  locale: 'he',
  isActive: false,
  createdAt: _now,
  updatedAt: _now,
  activeMembers: 4,
  adminCount: 1,
  shiftManagerCount: 0,
  employeeCount: 3,
  nfcTagsTotal: 1,
  nfcTagsActive: 0,
  staleOpenSessions: 0,
  exportsFailed24h: 0,
);

final _overview = PlatformOverview(
  totalStations: 2,
  activeStations: 1,
  inactiveStations: 1,
  activeMemberships: 16,
  stationAdminCount: 2,
  shiftManagerCount: 2,
  nfcTagsTotal: 3,
  nfcTagsActive: 1,
  staleOpenSessions: 0,
  failedExports24h: 0,
  pendingNotifications: 0,
  operationalAlertCount: 3,
  schemaVersion: '20260903000001',
  telemetryTimestamp: _now,
);

final _manager = PlatformStationManager(
  membershipId: 'mem-mgr',
  stationId: 'sta-kurdani',
  userId: 'usr-mgr',
  role: 'ADMIN',
  status: 'ACTIVE',
  joinedAt: _now,
  updatedAt: _now,
  firstName: 'Dana',
  lastName: 'Levi',
  email: 'dana@yellowshifts.local',
);

class FakePlatformAdminRepository implements PlatformAdminRepository {
  FakePlatformAdminRepository({
    this.createError,
    this.stations,
  });

  final Object? createError;
  final List<PlatformStationSummary>? stations;
  int createCalls = 0;
  int assignCalls = 0;
  int deactivateCalls = 0;
  int reactivateCalls = 0;
  String? lastCreateName;
  String? lastCreateCode;

  @override
  Future<bool> isPlatformAdmin() async => true;

  @override
  Future<PlatformOverview> getOverview() async => _overview;

  @override
  Future<List<PlatformStationSummary>> listStations() async =>
      stations ?? [_kurdani, _inactive];

  @override
  Future<StationCreateResult> createStation({
    required String name,
    required String code,
    String timezone = 'Asia/Jerusalem',
    String locale = 'he',
    int weekStart = 0,
    String? idempotencyKey,
    String? initialAdminUserId,
    String? initialAdminEmail,
    String? initialAdminFirstName,
    String? initialAdminLastName,
    String? initialAdminPhone,
  }) async {
    createCalls++;
    lastCreateName = name;
    lastCreateCode = code;
    if (createError != null) {
      throw createError!;
    }
    return const StationCreateResult(
      stationId: 'sta-new',
      name: 'New Station',
      code: 'NEW-01',
      idempotent: false,
      isNewUser: false,
    );
  }

  @override
  Future<void> updateStation({
    required String stationId,
    required String name,
    required String code,
    required String timezone,
    String locale = 'he',
    int weekStart = 0,
  }) async {}

  @override
  Future<void> setStationActive({
    required String stationId,
    required bool isActive,
    required String reason,
    bool forceDeactivate = false,
  }) async {
    if (isActive) {
      reactivateCalls++;
    } else {
      deactivateCalls++;
    }
  }

  @override
  Future<List<PlatformStationManager>> getStationManagers(
          String stationId) async =>
      [_manager];

  @override
  Future<StationManagerAssignmentResult> assignStationAdmin({
    required String stationId,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? replaceUserId,
    String? reason,
  }) async {
    assignCalls++;
    return const StationManagerAssignmentResult(
      membershipId: 'mem-new',
      userId: 'usr-new',
      isNewUser: false,
    );
  }

  @override
  Future<void> removeStationAdmin({
    required String stationId,
    required String userId,
    required String reason,
    String demoteTo = 'EMPLOYEE',
    bool deactivate = false,
  }) async {}

  @override
  Future<void> updateStationManager({
    required String stationId,
    required String userId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? employeeCode,
  }) async {}

  @override
  Future<String> resetManagerPassword({
    required String stationId,
    required String userId,
    String? newPassword,
  }) async =>
      newPassword ?? 'Ys#MockPass123';

  @override
  Future<PlatformAuditPage> queryAuditLogs({
    String? stationId,
    String? action,
    String? actorId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async =>
      const PlatformAuditPage(total: 0, limit: 50, offset: 0, entries: []);
}

StationAccessContext _platformAccess({bool operating = false}) {
  return StationAccessContext(
    isAuthenticated: true,
    hasActiveStation: operating,
    activeStationId: operating ? 'sta-kurdani' : null,
    isPlatformAdmin: true,
    operatingStationId: operating ? 'sta-kurdani' : null,
  );
}

StationAccessContext _stationAdminAccess() {
  return StationAccessContext(
    isAuthenticated: true,
    hasActiveStation: true,
    activeStationId: 'sta-kurdani',
    activeMembership: StationMembership(
      id: 'mem-adm',
      stationId: 'sta-kurdani',
      userId: 'usr-adm',
      role: StationRole.admin,
      status: MembershipStatus.active,
      joinedAt: _now,
    ),
  );
}

Widget _l10nApp({
  required Widget home,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class FakeAuthRepository implements AuthRepository {
  bool signedOut = false;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<UserProfile?> getCurrentProfile() async => null;

  @override
  Future<void> signInWithPassword(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {}
}

Widget _platformRouter({
  required String location,
  required FakePlatformAdminRepository repo,
  FakeAuthRepository? authRepo,
  StationAccessContext? access,
  Locale locale = const Locale('en'),
}) {
  final ctx = access ?? _platformAccess();
  final auth = authRepo ?? FakeAuthRepository();
  return ProviderScope(
    overrides: [
      platformAdminRepositoryProvider.overrideWithValue(repo),
      stationAccessContextProvider.overrideWith((ref) => ctx),
      authRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: location,
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                PlatformAdminShell(child: child),
            routes: [
              GoRoute(
                path: '/platform',
                builder: (context, state) => const PlatformOverviewScreen(),
              ),
              GoRoute(
                path: '/platform/stations',
                builder: (context, state) => const PlatformStationsScreen(),
              ),
              GoRoute(
                path: '/platform/stations/new',
                builder: (context, state) =>
                    const PlatformCreateStationScreen(),
              ),
              GoRoute(
                path: '/platform/stations/:stationId/managers',
                builder: (context, state) => PlatformStationManagersScreen(
                  stationId: state.pathParameters['stationId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Finder findAppButton(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is AppButton && widget.label == label,
  );
}

Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform Administration route guards', () {
    testWidgets('ordinary station admin cannot see platform data',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
          access: _stationAdminAccess(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Platform Administration unavailable'), findsOneWidget);
      expect(find.text('Total stations'), findsNothing);
      expect(find.textContaining('2'), findsNothing);
    });

    testWidgets('Platform Admin sees Platform Mode and overview',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Platform Mode'), findsWidgets);
      expect(find.text('Platform Overview'), findsOneWidget);
      expect(find.text('Total stations'), findsOneWidget);
      expect(find.text('Stations'), findsWidgets);
    });
  });

  group('Platform station list & create station', () {
    testWidgets('station list shows name, code, and employee counts',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kurdani'), findsOneWidget);
      expect(find.text('KRD-01'), findsOneWidget);
      expect(find.text('Haifa North'), findsOneWidget);
      expect(find.text('Create Station'), findsWidgets);
    });

    testWidgets('create station validates missing name/code', (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/new',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(findAppButton('Create Station'));
      await tester.tap(findAppButton('Create Station'));
      await tester.pumpAndSettle();

      expect(find.text('Please verify the entered details.'), findsOneWidget);
    });

    testWidgets('create station success navigates after repository call',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      final repo = FakePlatformAdminRepository();
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/new',
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Kurdani East');
      await tester.enterText(fields.at(1), 'KRD-02');
      await tester.ensureVisible(findAppButton('Create Station'));
      await tester.tap(findAppButton('Create Station'));
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(repo.lastCreateName, 'Kurdani East');
      expect(repo.lastCreateCode, 'KRD-02');
      expect(find.text('Kurdani'), findsOneWidget);
    });

    testWidgets('create station surfaces station code conflict',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      final repo = FakePlatformAdminRepository(
        createError: const StationCodeConflictFailure('exists'),
      );
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/new',
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Duplicate');
      await tester.enterText(fields.at(1), 'KRD-01');
      await tester.ensureVisible(findAppButton('Create Station'));
      await tester.tap(findAppButton('Create Station'));
      await tester.pumpAndSettle();

      expect(find.text('This station code is already in use.'), findsOneWidget);
    });
  });

  group('Manager assignment and station lifecycle confirmations', () {
    testWidgets('assign manager dialog submits email', (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      final repo = FakePlatformAdminRepository();
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/sta-kurdani/managers',
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dana Levi'), findsOneWidget);
      await tester.tap(findAppButton('Add Station Manager'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new.manager@yellowshifts.local');
      await tester.enterText(fields.at(1), 'Noa');
      await tester.enterText(fields.at(2), 'Cohen');
      await tester.tap(findAppButton('Assign Manager'));
      await tester.pumpAndSettle();

      expect(repo.assignCalls, 1);
    });

    testWidgets('deactivate station requires confirmation dialog',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      final repo = FakePlatformAdminRepository();
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/sta-kurdani/managers',
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deactivate Station'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate this station?'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Seasonal closure');
      await tester.tap(find.text('Deactivate Station').last);
      await tester.pumpAndSettle();
      expect(repo.deactivateCalls, 1);
    });

    testWidgets('reactivate station uses confirmation for inactive station',
        (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      final repo = FakePlatformAdminRepository(stations: [_inactive]);
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/sta-inactive/managers',
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reactivate Station'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Resume operations');
      await tester.tap(find.text('Reactivate Station').last);
      await tester.pumpAndSettle();
      expect(repo.reactivateCalls, 1);
    });
  });

  group('Operating-station context', () {
    testWidgets('banner shows operating station name for Platform Admin',
        (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          home: const Scaffold(body: PlatformScopeBanner()),
          overrides: [
            stationAccessContextProvider.overrideWith(
              (ref) => _platformAccess(operating: true),
            ),
            platformAdminRepositoryProvider
                .overrideWithValue(FakePlatformAdminRepository()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Operating: Kurdani'), findsOneWidget);
      expect(find.text('Return to Platform Administration'), findsOneWidget);
    });

    testWidgets('banner is hidden without operating context', (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          home: const Scaffold(body: PlatformScopeBanner()),
          overrides: [
            stationAccessContextProvider.overrideWith(
              (ref) => _platformAccess(),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.textContaining('Operating:'), findsNothing);
    });
  });

  group('Station Admin role UI restrictions', () {
    testWidgets('employee edit dropdown has Employee and Shift Manager only',
        (tester) async {
      final employee = EmployeeDetails(
        membershipId: 'mem-emp',
        stationId: 'sta-kurdani',
        userId: 'usr-emp',
        role: StationRole.employee,
        status: MembershipStatus.active,
        employeeCode: 'EMP-01',
        joinedAt: _now,
        firstName: 'Avi',
        lastName: 'Cohen',
        email: 'avi@yellowshifts.local',
      );

      await tester.pumpWidget(
        _l10nApp(
          home: Scaffold(body: EditEmployeeDialog(employee: employee)),
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<StationRole>>(
        find.byType(DropdownButton<StationRole>),
      );
      expect(
        dropdown.items!.map((item) => item.value),
        equals([StationRole.employee, StationRole.shiftManager]),
      );
      expect(find.text('Administrator'), findsNothing);
      expect(find.text('Station Manager'), findsNothing);
    });

    testWidgets('existing ADMIN membership is read-only in edit dialog',
        (tester) async {
      final adminEmployee = EmployeeDetails(
        membershipId: 'mem-adm',
        stationId: 'sta-kurdani',
        userId: 'usr-adm',
        role: StationRole.admin,
        status: MembershipStatus.active,
        employeeCode: 'ADM-01',
        joinedAt: _now,
        firstName: 'Dana',
        lastName: 'Levi',
        preferredLocale: 'he',
        email: 'dana@yellowshifts.local',
      );

      await tester.pumpWidget(
        _l10nApp(
          home: Scaffold(body: EditEmployeeDialog(employee: adminEmployee)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Station Manager'), findsOneWidget);
      expect(
        find.text(
            'Station Manager access is assigned only by Platform Administration.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<StationRole>), findsNothing);
    });

    testWidgets('ADMIN inspector hides role dropdown', (tester) async {
      final adminEmployee = EmployeeDetails(
        membershipId: 'mem-adm',
        stationId: 'sta-kurdani',
        userId: 'usr-adm',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: _now,
        firstName: 'Dana',
        lastName: 'Levi',
      );

      await tester.pumpWidget(
        _l10nApp(
          home: Scaffold(
            body: EmployeeDetailInspector(employee: adminEmployee),
          ),
          overrides: [
            stationAccessContextProvider.overrideWith(
              (ref) => _stationAdminAccess(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Station Manager'), findsWidgets);
      expect(
        find.text(
            'Station Manager access is assigned only by Platform Administration.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<StationRole>), findsNothing);
    });
  });

  group('Localization and responsive layouts', () {
    testWidgets('Hebrew RTL platform overview', (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('סקירת פלטפורמה'), findsOneWidget);
      expect(find.text('מצב פלטפורמה'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.text('סקירת פלטפורמה'))),
        TextDirection.rtl,
      );
    });

    testWidgets('English LTR platform overview', (tester) async {
      await setSurface(tester, const Size(1280, 1400));
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Platform Overview'), findsOneWidget);
      expect(find.text('Platform Mode'), findsWidgets);
    });

    for (final width in [320, 360, 390, 430, 768, 1024, 1280, 1440, 1920]) {
      testWidgets('platform stations layout at ${width}px', (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _platformRouter(
            location: '/platform/stations',
            repo: FakePlatformAdminRepository(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kurdani'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width < 768) {
          expect(find.byType(DataTable), findsNothing);
        } else {
          expect(find.byType(DataTable), findsOneWidget);
        }
      });
    }

    testWidgets('create station form is usable at 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/new',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Station Name'), findsOneWidget);
      expect(find.text('Create Station'), findsWidgets);
    });

    testWidgets(
        'PlatformAdminShell renders unauthorized screen when user is not a platform admin',
        (tester) async {
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
          access: _stationAdminAccess(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Platform Administration unavailable'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets(
        'PlatformAdminShell renders empty scaffold without error when unauthenticated',
        (tester) async {
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
          access: StationAccessContext.unauthenticated(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PlatformAdminShell displays confirmation dialog and triggers logout',
        (tester) async {
      final fakeAuth = FakeAuthRepository();
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform',
          repo: FakePlatformAdminRepository(),
          authRepo: fakeAuth,
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the logout button by icon
      final logoutBtn = find.byIcon(LucideIcons.logOut);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap confirm Sign Out in the dialog
      final confirmBtn =
          find.widgetWithText(ElevatedButton, 'Sign Out from YellowShifts');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify signOut was called
      expect(fakeAuth.signedOut, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Platform Station Managers screen renders edit and reset password actions',
        (tester) async {
      await tester.pumpWidget(
        _platformRouter(
          location: '/platform/stations/sta-kurdani/managers',
          repo: FakePlatformAdminRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kurdani'), findsOneWidget);
      expect(find.text('Edit Manager'), findsOneWidget);
      expect(find.text('Set Password'), findsOneWidget);
      expect(find.text('Dana Levi'), findsOneWidget);
    });
  });
}
