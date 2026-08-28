import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';
import 'package:yellowshifts/features/attendance/domain/models/kiosk_device.dart';
import 'package:yellowshifts/features/attendance/domain/models/qr_challenge.dart';
import 'package:yellowshifts/features/attendance/domain/models/presence_proof.dart';
import 'package:yellowshifts/features/attendance/domain/models/attendance_record.dart';
import 'package:yellowshifts/features/attendance/domain/models/live_attendance_roster.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/attendance_status_card.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/kiosk_health_badge.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/shift_preview_modal.dart';
import 'package:yellowshifts/features/attendance/presentation/widgets/attendance_scanner_modal.dart';

void main() {
  group('Phase 4: Domain Models Unit Tests', () {
    test('KioskDevice JSON parsing and isOnline calculation', () {
      final now = DateTime.now().toUtc();
      final recentSeen = now.subtract(const Duration(minutes: 1));
      final staleSeen = now.subtract(const Duration(minutes: 10));

      final onlineDevice = KioskDevice.fromJson({
        'id': 'k-01',
        'station_id': 's-01',
        'name': 'Front Tablet',
        'device_identifier': 'TAB-01',
        'credential_version': 2,
        'is_active': true,
        'last_seen_at': recentSeen.toIso8601String(),
        'created_by': 'u-01',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      expect(onlineDevice.name, 'Front Tablet');
      expect(onlineDevice.credentialVersion, 2);
      expect(onlineDevice.isOnline, isTrue);

      final staleDevice = KioskDevice.fromJson({
        'id': 'k-02',
        'station_id': 's-01',
        'name': 'Back Tablet',
        'device_identifier': 'TAB-02',
        'credential_version': 1,
        'is_active': true,
        'last_seen_at': staleSeen.toIso8601String(),
        'created_by': 'u-01',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      expect(staleDevice.isOnline, isFalse);
    });

    test('QrChallenge remaining progress and expiration', () {
      final now = DateTime.now().toUtc();
      final futureExp = now.add(const Duration(seconds: 15));
      final pastExp = now.subtract(const Duration(seconds: 5));

      final activeChallenge = QrChallenge.fromJson({
        'qr_token': 'token-xyz-12345',
        'display_code': 'ABC890',
        'expires_at': futureExp.toIso8601String(),
        'ttl_seconds': 30,
        'station_id': 's-01',
        'station_name': 'Kiryat Motzkin Station',
        'server_time': now.toIso8601String(),
      });

      expect(activeChallenge.isExpired, isFalse);
      expect(activeChallenge.remainingProgress, greaterThan(0.0));
      expect(activeChallenge.remainingProgress, lessThanOrEqualTo(1.0));

      final expiredChallenge = QrChallenge.fromJson({
        'qr_token': 'token-expired',
        'display_code': 'EXP000',
        'expires_at': pastExp.toIso8601String(),
        'ttl_seconds': 30,
        'station_id': 's-01',
        'station_name': 'Kiryat Motzkin Station',
        'server_time': now.toIso8601String(),
      });

      expect(expiredChallenge.isExpired, isTrue);
      expect(expiredChallenge.remainingProgress, equals(0.0));
    });

    test('PresenceProof JSON parsing and action mapping', () {
      final now = DateTime.now().toUtc();
      final inProof = PresenceProof.fromJson({
        'presence_proof_token': 'proof-in-1',
        'action': 'CHECK_IN',
        'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
        'station_id': 's-01',
        'station_name': 'Station Alpha',
        'shift_preview': const {'shift_name': 'Morning Shift'},
      });

      expect(inProof.action, AttendanceAction.checkIn);
      expect(inProof.shiftPreview?['shift_name'], 'Morning Shift');

      final outProof = PresenceProof.fromJson({
        'presence_proof_token': 'proof-out-1',
        'action': 'CHECK_OUT',
        'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
        'station_id': 's-01',
        'station_name': 'Station Alpha',
      });

      expect(outProof.action, AttendanceAction.checkOut);
    });

    test('AttendanceRecord parsing and elapsed minutes', () {
      final now = DateTime.now().toUtc();
      final checkInTime = now.subtract(const Duration(hours: 2));

      final openRecord = AttendanceRecord.fromJson({
        'id': 'att-01',
        'station_id': 's-01',
        'shift_name': 'Afternoon Shift',
        'check_in_time': checkInTime.toIso8601String(),
        'check_out_time': null,
        'worked_minutes': null,
        'late_minutes': 10,
        'status': 'OPEN',
        'verification_method': 'QR_ONLY',
      });

      expect(openRecord.isOpen, isTrue);
      expect(openRecord.lateMinutes, 10);
      expect(openRecord.currentElapsedMinutes, greaterThanOrEqualTo(119));

      final completedRecord = AttendanceRecord.fromJson({
        'id': 'att-02',
        'station_id': 's-01',
        'shift_name': 'Morning Shift',
        'check_in_time': checkInTime.toIso8601String(),
        'check_out_time': now.toIso8601String(),
        'worked_minutes': 120,
        'late_minutes': 0,
        'status': 'COMPLETED',
        'verification_method': 'QR_PLUS_IDENTITY',
      });

      expect(completedRecord.isOpen, isFalse);
      expect(completedRecord.status, AttendanceStatus.completed);
      expect(completedRecord.workedMinutes, 120);
      expect(completedRecord.currentElapsedMinutes, 120);
    });

    test('LiveAttendanceResponse and Roster parsing', () {
      final now = DateTime.now().toUtc();
      final res = LiveAttendanceResponse.fromJson({
        'success': true,
        'station_id': 's-01',
        'target_date': '2026-08-26',
        'kpis': const {
          'currently_working': 3,
          'scheduled_upcoming': 5,
          'late_checked_in': 1,
          'completed': 4,
          'not_checked_in': 0,
        },
        'roster': [
          {
            'shift_id': 'sh-01',
            'shift_name': 'Morning Shift',
            'starts_at':
                now.subtract(const Duration(hours: 1)).toIso8601String(),
            'ends_at': now.add(const Duration(hours: 7)).toIso8601String(),
            'assignment_id': 'asg-01',
            'user_id': 'u-01',
            'first_name': 'Anas',
            'last_name': 'Zangeel',
            'employee_code': 'EMP-01',
            'attendance_id': 'att-01',
            'check_in_time':
                now.subtract(const Duration(hours: 1)).toIso8601String(),
            'operational_status': 'WORKING',
            'elapsed_minutes': 60,
            'late_minutes': 0,
          }
        ],
      });

      expect(res.kpis.currentlyWorking, 3);
      expect(res.kpis.completed, 4);
      expect(res.roster.length, 1);
      expect(res.roster.first.fullName, 'Anas Zangeel');
      expect(res.roster.first.operationalStatus, LiveRosterStatus.working);
      expect(res.roster.first.elapsedMinutes, 60);
    });
  });

  group('Phase 4: Widget Tests', () {
    testWidgets('AttendanceStatusCard displays not checked in state',
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

      expect(find.text('Not Checked In'), findsOneWidget);
      expect(find.text('Scan Station QR'), findsOneWidget);

      await tester.tap(find.text('Scan Station QR'));
      expect(scanTapped, isTrue);
    });

    testWidgets(
        'AttendanceStatusCard displays currently working state with timer',
        (tester) async {
      bool checkOutTapped = false;
      final record = AttendanceRecord(
        id: 'att-1',
        stationId: 's-1',
        shiftName: 'Night Shift',
        checkInTime:
            DateTime.now().toUtc().subtract(const Duration(minutes: 45)),
        lateMinutes: 15,
        status: AttendanceStatus.open,
        verificationMethod: AttendanceVerificationMethod.qrOnly,
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

      expect(find.text('CURRENTLY WORKING'), findsOneWidget);
      expect(find.text('Night Shift'), findsOneWidget);
      expect(find.text('Late 15 min'), findsOneWidget);
      expect(find.text('Scan QR to Check Out'), findsOneWidget);

      await tester.tap(find.text('Scan QR to Check Out'));
      expect(checkOutTapped, isTrue);
    });

    testWidgets('KioskHealthBadge renders Online, Offline, and Inactive states',
        (tester) async {
      final now = DateTime.now().toUtc();

      final online = KioskDevice(
        id: 'k1',
        stationId: 's1',
        name: 'Kiosk 1',
        deviceIdentifier: 'K-01',
        credentialVersion: 1,
        isActive: true,
        lastSeenAt: now.subtract(const Duration(seconds: 30)),
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      final inactive = KioskDevice(
        id: 'k2',
        stationId: 's1',
        name: 'Kiosk 2',
        deviceIdentifier: 'K-02',
        credentialVersion: 1,
        isActive: false,
        lastSeenAt: now,
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(
              children: [
                KioskHealthBadge(device: online),
                KioskHealthBadge(device: inactive),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('ShiftPreviewModal renders shift details and confirms check-in',
        (tester) async {
      bool confirmed = false;
      final proof = PresenceProof(
        presenceProofToken: 'proof-token',
        action: AttendanceAction.checkIn,
        expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
        stationId: 's-01',
        stationName: 'Kiryat Motzkin Station',
        shiftPreview: const {
          'shift_name': 'Morning Shift',
          'starts_at': '2026-08-26T08:00:00Z',
          'ends_at': '2026-08-26T16:00:00Z',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ShiftPreviewModal(
              proof: proof,
              onConfirm: () => confirmed = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirm Check-In'), findsOneWidget);
      expect(find.text('Kiryat Motzkin Station'), findsOneWidget);
      expect(find.text('Morning Shift'), findsOneWidget);
      expect(find.text('Check In Now'), findsOneWidget);

      await tester.tap(find.text('Check In Now'));
      expect(confirmed, isTrue);
    });

    testWidgets('KioskHealthBadge renders offline state', (tester) async {
      final now = DateTime.now().toUtc();
      final offlineDevice = KioskDevice(
        id: 'k3',
        stationId: 's1',
        name: 'Kiosk 3',
        deviceIdentifier: 'K-03',
        credentialVersion: 1,
        isActive: true,
        lastSeenAt: now.subtract(const Duration(minutes: 10)),
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: KioskHealthBadge(device: offlineDevice),
          ),
        ),
      );

      expect(find.text('Offline / Idle'), findsOneWidget);
    });

    testWidgets('Attendance widgets render completely in Hebrew locale',
        (tester) async {
      // 1. AttendanceStatusCard in Hebrew (Not Checked In)
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('he'),
          home: Scaffold(
            body: AttendanceStatusCard(
              openAttendance: null,
              onScanTap: () {},
              onCheckOutTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('טרם נכנסת למשמרת'), findsOneWidget);
      expect(find.text('סרוק קוד עמדה'), findsOneWidget);

      // 2. AttendanceStatusCard in Hebrew (Working)
      final workingRecord = AttendanceRecord(
        id: 'att-he-1',
        stationId: 's-he-1',
        shiftName: 'משמרת בוקר',
        checkInTime:
            DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
        lateMinutes: 5,
        status: AttendanceStatus.open,
        verificationMethod: AttendanceVerificationMethod.qrOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('he'),
          home: Scaffold(
            body: AttendanceStatusCard(
              openAttendance: workingRecord,
              onScanTap: () {},
              onCheckOutTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('במשמרת פעילה כעת'), findsOneWidget);
      expect(find.text('משמרת בוקר'), findsOneWidget);
      expect(find.text('איחור של 5 דק\''), findsOneWidget);
      expect(find.text('סרוק ליציאה ממשמרת'), findsOneWidget);

      // 3. ShiftPreviewModal in Hebrew
      final proof = PresenceProof(
        presenceProofToken: 'proof-token',
        action: AttendanceAction.checkIn,
        expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
        stationId: 's-01',
        stationName: 'תחנת יילו כורדני',
        shiftPreview: const {
          'shift_name': 'משמרת ערב',
          'starts_at': '2026-08-28T16:00:00Z',
          'ends_at': '2026-08-28T23:00:00Z',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('he'),
          home: Scaffold(
            body: ShiftPreviewModal(
              proof: proof,
              onConfirm: () {},
            ),
          ),
        ),
      );

      expect(find.text('אישור כניסה למשמרת'), findsOneWidget);
      expect(find.text('תחנת יילו כורדני'), findsOneWidget);
      expect(find.text('משמרת ערב'), findsOneWidget);
      expect(find.text('היכנס למשמרת עכשיו'), findsOneWidget);

      // 4. Scanner modal tabs in Hebrew
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('he'),
          home: Scaffold(
            body: AttendanceScannerModal(
              onCodeDetected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('סריקת מצלמה'), findsOneWidget);
      expect(find.text('הזנת קוד ידני'), findsOneWidget);
    });
  });
}
