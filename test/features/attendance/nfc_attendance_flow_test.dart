import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yellowshifts/core/auth/auth_state_provider.dart';
import 'package:yellowshifts/core/errors/app_failure.dart';
import 'package:yellowshifts/features/attendance/data/attendance_repository.dart';
import 'package:yellowshifts/features/attendance/data/nfc_tag_repository.dart';
import 'package:yellowshifts/features/attendance/domain/models/attendance_record.dart';
import 'package:yellowshifts/features/attendance/domain/models/live_attendance_roster.dart';
import 'package:yellowshifts/features/attendance/domain/models/station_nfc_tag.dart';
import 'package:yellowshifts/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:yellowshifts/features/attendance/presentation/providers/nfc_providers.dart';
import 'package:yellowshifts/features/attendance/presentation/screens/nfc_attendance_verification_screen.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/attendance_status_card.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/nfc_provision_dialog.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  bool processSuccess = true;
  String? processAction; // 'CHECK_IN' or 'CHECK_OUT'
  String? errorMessage;
  String? errorCode;
  int punchCalls = 0;

  @override
  Future<Map<String, dynamic>> nfcProcessAttendance({
    required String token,
    Map<String, dynamic>? clientLocation,
  }) async {
    punchCalls++;
    if (!processSuccess) {
      if (errorCode != null) {
        throw DatabaseFailure(errorMessage ?? 'Error', code: errorCode);
      }
      throw Exception(errorMessage ?? 'Attendance verification failed');
    }
    if (processAction == 'CHECK_OUT') {
      return {
        'success': true,
        'action': 'CHECK_OUT',
        'attendance_id': 'att-123',
        'station_id': 'sta-1',
        'station_name': 'Station Alpha',
        'station_code': 'ST-ALPHA',
        'tag_name': 'Main Entrance Tag',
        'check_in_time': DateTime.now()
            .subtract(const Duration(hours: 4))
            .toUtc()
            .toIso8601String(),
        'check_out_time': DateTime.now().toUtc().toIso8601String(),
        'worked_minutes': 240,
        'status': 'COMPLETED',
        'server_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return {
      'success': true,
      'action': 'CHECK_IN',
      'attendance_id': 'att-123',
      'station_id': 'sta-1',
      'station_name': 'Station Alpha',
      'station_code': 'ST-ALPHA',
      'tag_name': 'Main Entrance Tag',
      'shift_name': 'Morning Shift',
      'check_in_time': DateTime.now().toUtc().toIso8601String(),
      'late_minutes': 0,
      'status': 'OPEN',
      'server_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> nfcCheckIn({
    required String tagIdentifier,
    required String tagSecret,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> nfcCheckOut({
    required String tagIdentifier,
    required String tagSecret,
  }) async =>
      {'success': true};

  @override
  Future<LiveAttendanceResponse> getManagerLiveAttendance({
    required String stationId,
    String? targetDate,
  }) async {
    return const LiveAttendanceResponse(
      success: true,
      stationId: 'st-1',
      targetDate: '2026-09-04',
      kpis: LiveAttendanceKpis(
        currentlyWorking: 1,
        scheduledUpcoming: 2,
        lateCheckedIn: 0,
        completed: 1,
        notCheckedIn: 0,
      ),
      roster: [],
    );
  }

  @override
  Future<List<AttendanceRecord>> getMyAttendanceHistory({
    required String stationId,
    DateTime? from,
    DateTime? to,
    int limit = 20,
    int offset = 0,
  }) async =>
      [];

  @override
  Future<AttendanceRecord?> getMyOpenAttendance(String stationId) async => null;

  @override
  Future<void> correctAttendanceRecord({
    required String attendanceRecordId,
    required DateTime newCheckIn,
    required DateTime newCheckOut,
    required String reason,
  }) async {}
}

class FakeNfcTagRepository implements NfcTagRepository {
  bool provisionSuccess = true;
  String? generatedToken;

  @override
  Future<Map<String, dynamic>> provisionStationNfcTag({
    required String stationId,
    required String name,
  }) async {
    final token = generatedToken ??
        '8cd51f15a8d746f0b52d92e08713c1d78cd51f15a8d746f0b52d92e08713c1d7';
    return {
      'id': 'tag-123',
      'station_id': stationId,
      'name': name,
      'tag_identifier': 'TAG-ALPHA-01',
      'token': token,
      'raw_secret': token,
      'nfc_url': '/nfc/t/$token',
      'is_active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> regenerateStationNfcTag(String tagId) async {
    const token =
        'newtoken99999999999999999999999999999999999999999999999999999999';
    return {
      'id': tagId,
      'token': token,
      'nfc_url': '/nfc/t/$token',
    };
  }

  @override
  Future<List<StationNfcTag>> listStationNfcTags(String stationId) async => [];

  @override
  Future<void> reactivateStationNfcTag(String tagId) async {}

  @override
  Future<Map<String, dynamic>> replaceStationNfcTag(
          {required String oldTagId, required String newName}) async =>
      {};

  @override
  Future<void> revokeStationNfcTag(String tagId) async {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('NfcAttendanceVerificationScreen', () {
    testWidgets('processes Check-In successfully and renders verified state',
        (tester) async {
      final fakeRepo = FakeAttendanceRepository()..processAction = 'CHECK_IN';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(null),
            attendanceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NfcAttendanceVerificationScreen(
              token: '8cd51f15a8d746f0b52d92e08713c1d7',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.punchCalls, 1);
      expect(find.text('Shift Started Successfully'), findsOneWidget);
      expect(find.text('Station Alpha'), findsOneWidget);
      expect(find.text('Morning Shift'), findsOneWidget);
      expect(find.text('Server Time Confirmed'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
    });

    testWidgets('processes Check-Out successfully and displays worked duration',
        (tester) async {
      final fakeRepo = FakeAttendanceRepository()..processAction = 'CHECK_OUT';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(null),
            attendanceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NfcAttendanceVerificationScreen(
              token: '8cd51f15a8d746f0b52d92e08713c1d7',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.punchCalls, 1);
      expect(find.text('Shift Ended Successfully'), findsOneWidget);
      expect(find.text('Station Alpha'), findsOneWidget);
      expect(find.text('Worked Duration'), findsOneWidget);
      expect(find.text('4 hrs'), findsOneWidget);
    });

    testWidgets('renders localized error state when token is invalid',
        (tester) async {
      final fakeRepo = FakeAttendanceRepository()
        ..processSuccess = false
        ..errorCode = 'P0020'
        ..errorMessage = 'Invalid or missing NFC station token';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(null),
            attendanceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NfcAttendanceVerificationScreen(
              token: 'invalid_token_123',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Attendance Verification Failed'), findsOneWidget);
      expect(find.text('Invalid or expired NFC tag token.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry to re-trigger punch
      fakeRepo.processSuccess = true;
      fakeRepo.processAction = 'CHECK_IN';
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.punchCalls, 2);
      expect(find.text('Shift Started Successfully'), findsOneWidget);
    });

    testWidgets('renders duplicate punch cooldown warning cleanly',
        (tester) async {
      final fakeRepo = FakeAttendanceRepository()
        ..processSuccess = false
        ..errorCode = 'P0028'
        ..errorMessage = 'Duplicate punch detected: please wait a moment';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(null),
            attendanceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NfcAttendanceVerificationScreen(
              token: '8cd51f15a8d746f0b52d92e08713c1d7',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Attendance Verification Failed'), findsOneWidget);
      expect(
          find.text(
              'Duplicate punch detected. Please wait a moment before tapping again.'),
          findsOneWidget);
    });
  });

  group('AttendanceStatusCard Widget', () {
    testWidgets('renders Not Checked In with tap physical NFC instructions',
        (tester) async {
      bool testTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: AttendanceStatusCard(
              openAttendance: null,
              onTestNfcTap: () => testTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not Checked In'), findsOneWidget);
      expect(find.byIcon(LucideIcons.radio), findsOneWidget);
      expect(
          find.text(
              'Tap the physical NFC tag at your workplace with your phone to start or end your shift.'),
          findsOneWidget);
      expect(find.text('Simulate / Test NFC URL'), findsOneWidget);

      await tester.tap(find.text('Simulate / Test NFC URL'));
      expect(testTapped, true);
    });

    testWidgets(
        'renders Active Shift state with live timer and checkout prompt',
        (tester) async {
      final record = AttendanceRecord(
        id: 'rec-1',
        stationId: 'st-1',
        shiftName: 'Evening Shift',
        checkInTime: DateTime.now().subtract(const Duration(minutes: 45)),
        lateMinutes: 10,
        status: AttendanceStatus.open,
        verificationMethod: AttendanceVerificationMethod.nfc,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: AttendanceStatusCard(
              openAttendance: record,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Evening Shift'), findsOneWidget);
      expect(find.text('CURRENTLY WORKING'), findsOneWidget);
      expect(find.text('Late 10 min'), findsOneWidget);
      expect(
          find.text(
              'Tap the physical NFC tag at your workplace with your phone to start or end your shift.'),
          findsOneWidget);
    });
  });

  group('NfcProvisionDialog Widget', () {
    testWidgets(
        'provisions new tag and displays exact NDEF URL with copy action',
        (tester) async {
      final fakeTagRepo = FakeNfcTagRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nfcTagRepositoryProvider.overrideWithValue(fakeTagRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: NfcProvisionDialog(stationId: 'sta-alpha'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Provision New NFC Tag'), findsOneWidget);
      expect(find.text('Register Tag'), findsOneWidget);

      // Enter name and register
      await tester.enterText(find.byType(TextField), 'Front Desk Tag');
      await tester.tap(find.text('Register Tag'));
      await tester.pumpAndSettle();

      // Verified URL Presentation
      expect(find.text('NFC Tag URL'), findsWidgets);
      expect(find.textContaining('/nfc/t/8cd51f15a8d746f0b52d92e08713c1d7'),
          findsOneWidget);
      expect(find.text('Copy NFC URL'), findsOneWidget);
      expect(find.byIcon(LucideIcons.copy), findsWidgets);
    });
  });
}
