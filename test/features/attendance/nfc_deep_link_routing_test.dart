import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yellowshifts/app/routing/app_router.dart';
import 'package:yellowshifts/core/auth/auth_state_provider.dart';
import 'package:yellowshifts/core/permissions/platform_admin_provider.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/attendance/data/attendance_repository.dart';
import 'package:yellowshifts/features/attendance/domain/models/attendance_record.dart';
import 'package:yellowshifts/features/attendance/domain/models/live_attendance_roster.dart';
import 'package:yellowshifts/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:yellowshifts/features/attendance/presentation/screens/nfc_attendance_verification_screen.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

class FakeAttendanceRepo implements AttendanceRepository {
  @override
  Future<Map<String, dynamic>> nfcProcessAttendance({
    required String token,
    Map<String, dynamic>? clientLocation,
  }) async {
    return {
      'success': true,
      'action': 'CHECK_IN',
      'station_name': 'Station Alpha',
      'server_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> nfcCheckIn(
          {required String tagIdentifier, required String tagSecret}) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> nfcCheckOut(
          {required String tagIdentifier, required String tagSecret}) async =>
      {'success': true};

  @override
  Future<LiveAttendanceResponse> getManagerLiveAttendance(
          {required String stationId, String? targetDate}) async =>
      const LiveAttendanceResponse(
        success: true,
        stationId: 'st-1',
        targetDate: '2026-09-04',
        kpis: LiveAttendanceKpis(
          currentlyWorking: 1,
          scheduledUpcoming: 1,
          lateCheckedIn: 0,
          completed: 1,
          notCheckedIn: 0,
        ),
        roster: [],
      );

  @override
  Future<List<AttendanceRecord>> getMyAttendanceHistory(
          {required String stationId,
          DateTime? from,
          DateTime? to,
          int limit = 20,
          int offset = 0}) async =>
      [];

  @override
  Future<AttendanceRecord?> getMyOpenAttendance(String stationId) async => null;

  @override
  Future<void> correctAttendanceRecord(
      {required String attendanceRecordId,
      required DateTime newCheckIn,
      required DateTime newCheckOut,
      required String reason}) async {}
}

class FakeBuildContext extends Fake implements BuildContext {}

GoRouterState _makeState(String path,
    {String? fullPath, Map<String, String> params = const {}}) {
  final uri = Uri.parse(path);
  final router = GoRouter(routes: []);
  return GoRouterState(
    router.configuration,
    uri: uri,
    matchedLocation: uri.path,
    fullPath: fullPath ?? uri.path,
    pathParameters: params,
    pageKey: const ValueKey('test'),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('NFC Deep-Link Routing Redirection (RouterNotifier)', () {
    test(
        'unauthenticated user accessing /nfc/t/:token redirects to /login?redirect=... preserving intent',
        () {
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          isPlatformAdminProvider.overrideWith((ref) => false),
          stationAccessContextProvider
              .overrideWithValue(StationAccessContext.unauthenticated()),
        ],
      );

      final notifier = container.read(routerNotifierProvider);
      final fakeContext = FakeBuildContext();
      final state = _makeState(
        '/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7',
        fullPath: '/nfc/t/:token',
        params: {'token': '8cd51f15a8d746f0b52d92e08713c1d7'},
      );

      final redirectResult = notifier.redirect(fakeContext, state);

      expect(redirectResult,
          '/login?redirect=%2Fnfc%2Ft%2F8cd51f15a8d746f0b52d92e08713c1d7');
    });

    test(
        'authenticated user accessing /nfc/t/:token is permitted directly (returns null)',
        () {
      final fakeUser = User(
        id: 'user-emp-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(fakeUser),
          isPlatformAdminProvider.overrideWith((ref) => false),
          stationAccessContextProvider.overrideWithValue(
            const StationAccessContext(
              isAuthenticated: true,
              hasActiveStation: true,
              activeStationId: 'sta-1',
            ),
          ),
        ],
      );

      final notifier = container.read(routerNotifierProvider);
      final fakeContext = FakeBuildContext();
      final state = _makeState(
        '/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7',
        fullPath: '/nfc/t/:token',
        params: {'token': '8cd51f15a8d746f0b52d92e08713c1d7'},
      );

      final redirectResult = notifier.redirect(fakeContext, state);

      expect(redirectResult, isNull);
    });

    test(
        'authenticated user on /login with redirect query param resumes navigation to NFC target',
        () {
      final fakeUser = User(
        id: 'user-emp-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(fakeUser),
          isPlatformAdminProvider.overrideWith((ref) => false),
          stationAccessContextProvider.overrideWithValue(
            const StationAccessContext(
              isAuthenticated: true,
              hasActiveStation: true,
              activeStationId: 'sta-1',
            ),
          ),
        ],
      );

      final notifier = container.read(routerNotifierProvider);
      final fakeContext = FakeBuildContext();
      final state = _makeState(
        '/login?redirect=/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7',
        fullPath: '/login',
      );

      final redirectResult = notifier.redirect(fakeContext, state);

      expect(redirectResult, '/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7');
    });

    testWidgets(
        'NfcAttendanceVerificationScreen mounts and renders correctly via GoRouter path parameters',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          attendanceRepositoryProvider.overrideWithValue(FakeAttendanceRepo()),
        ],
      );

      final testRouter = GoRouter(
        initialLocation: '/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7',
        routes: [
          GoRoute(
            path: '/nfc/t/:token',
            builder: (context, state) => NfcAttendanceVerificationScreen(
              token: state.pathParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Text('Dashboard')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: testRouter,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(NfcAttendanceVerificationScreen), findsOneWidget);
      expect(find.text('Shift Started Successfully'), findsOneWidget);
    });
  });
}
