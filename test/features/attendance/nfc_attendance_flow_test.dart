import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yellowshifts/core/nfc/nfc_service.dart';
import 'package:yellowshifts/features/attendance/data/attendance_repository.dart';
import 'package:yellowshifts/features/attendance/domain/models/attendance_record.dart';
import 'package:yellowshifts/features/attendance/domain/models/live_attendance_roster.dart';
import 'package:yellowshifts/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/attendance_status_card.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/nfc_scanner_modal.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  bool checkInSuccess = true;
  String? checkInError;

  @override
  Future<Map<String, dynamic>> nfcCheckIn({
    required String tagIdentifier,
    required String tagSecret,
  }) async {
    if (!checkInSuccess) {
      throw Exception(checkInError ?? 'Check-in failed');
    }
    return {'success': true, 'record_id': 'rec-1'};
  }

  @override
  Future<Map<String, dynamic>> nfcCheckOut({
    required String tagIdentifier,
    required String tagSecret,
  }) async {
    return {'success': true, 'record_id': 'rec-1', 'worked_minutes': 480};
  }

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
        currentlyWorking: 2,
        scheduledUpcoming: 3,
        lateCheckedIn: 0,
        completed: 3,
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
  }) async {
    return [];
  }

  @override
  Future<AttendanceRecord?> getMyOpenAttendance(String stationId) async {
    return null;
  }

  @override
  Future<void> correctAttendanceRecord({
    required String attendanceRecordId,
    required DateTime newCheckIn,
    required DateTime newCheckOut,
    required String reason,
  }) async {}
}

class TestMockNfcService implements NfcService {
  bool isAvailableVal = true;
  String? errorMessage;
  NfcStationTagPayload? payloadToReturn;

  @override
  Future<bool> isAvailable() async => isAvailableVal;

  @override
  Future<void> startStationTagScan({
    required void Function(NfcStationTagPayload payload) onTagScanned,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    if (!isAvailableVal) {
      onError('NFC is unavailable');
      return;
    }
    if (errorMessage != null) {
      onError(errorMessage!);
      return;
    }
    if (payloadToReturn != null) {
      onTagScanned(payloadToReturn!);
    }
  }

  @override
  Future<void> writeStationTag({
    required NfcStationTagPayload payload,
    required void Function() onSuccess,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    if (isAvailableVal) {
      onSuccess();
    } else {
      onError('NFC unavailable');
    }
  }

  @override
  Future<void> stopSession(
      {String? alertMessage, String? errorMessage}) async {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AttendanceStatusCard Widget', () {
    testWidgets('renders Not Checked In state and triggers scan on tap',
        (tester) async {
      bool scanTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: AttendanceStatusCard(
              openAttendance: null,
              onScanTap: () => scanTapped = true,
              onCheckOutTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not Checked In'), findsOneWidget);
      expect(find.byIcon(LucideIcons.radio), findsNWidgets(2));
      expect(find.text('Scan Station NFC Tag'), findsOneWidget);

      await tester.tap(find.text('Scan Station NFC Tag'));
      expect(scanTapped, true);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renders Active Shift state and triggers check-out',
        (tester) async {
      bool checkOutTapped = false;
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
              onScanTap: () {},
              onCheckOutTap: () => checkOutTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Evening Shift'), findsOneWidget);
      expect(find.text('CURRENTLY WORKING'), findsOneWidget);
      expect(find.text('Late 10 min'), findsOneWidget);
      expect(find.text('Check Out'), findsOneWidget);

      await tester.tap(find.text('Check Out'));
      expect(checkOutTapped, true);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('NfcScannerModal Widget', () {
    testWidgets('renders scanning state and responds to mock NFC scan',
        (tester) async {
      final mockNfc = TestMockNfcService();
      final mockRepo = FakeAttendanceRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nfcServiceProvider.overrideWithValue(mockNfc),
            attendanceRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: NfcScannerModal(isCheckIn: true),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Scan Station NFC Tag'), findsOneWidget);
      expect(find.byIcon(LucideIcons.radio), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('displays error state when NFC is disabled or unavailable',
        (tester) async {
      final mockNfc = TestMockNfcService()..isAvailableVal = false;
      final mockRepo = FakeAttendanceRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nfcServiceProvider.overrideWithValue(mockNfc),
            attendanceRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: NfcScannerModal(isCheckIn: true),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Attendance Verification Failed'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
