import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/nfc/nfc_service.dart';
import 'package:yellowshifts/features/attendance/domain/models/attendance_record.dart';
import 'package:yellowshifts/features/attendance/domain/models/station_nfc_tag.dart';

class MockNfcService implements NfcService {
  bool isAvailableResult = true;
  NfcStationTagPayload? tagToDiscover;
  String? errorToEmit;
  bool writeShouldSucceed = true;
  bool wasStopSessionCalled = false;

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Future<void> startStationTagScan({
    required void Function(NfcStationTagPayload payload) onTagScanned,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    if (!isAvailableResult) {
      onError('NFC is unavailable');
      return;
    }
    if (errorToEmit != null) {
      onError(errorToEmit!);
      return;
    }
    if (tagToDiscover != null) {
      onTagScanned(tagToDiscover!);
    }
  }

  @override
  Future<void> writeStationTag({
    required NfcStationTagPayload payload,
    required void Function() onSuccess,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    if (!isAvailableResult) {
      onError('NFC is unavailable');
      return;
    }
    if (writeShouldSucceed) {
      onSuccess();
    } else {
      onError(errorToEmit ?? 'Write failed');
    }
  }

  @override
  Future<void> stopSession({String? alertMessage, String? errorMessage}) async {
    wasStopSessionCalled = true;
  }
}

void main() {
  group('NfcStationTagPayload Serialization & Parsing', () {
    test('serializes and parses valid payload correctly', () {
      const payload = NfcStationTagPayload(
        version: 1,
        stationCode: 'YS-TLV-01',
        tagIdentifier: 'ytag_1234567890abcdef',
        rawSecret: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      );

      final jsonStr = payload.serialize();
      final parsed = NfcStationTagPayload.parseRawString(jsonStr);

      expect(parsed, isNotNull);
      expect(parsed!.version, 1);
      expect(parsed.stationCode, 'YS-TLV-01');
      expect(parsed.tagIdentifier, 'ytag_1234567890abcdef');
      expect(parsed.rawSecret, payload.rawSecret);
    });

    test('rejects invalid or corrupted payload strings', () {
      expect(NfcStationTagPayload.parseRawString('not-json'), isNull);
      expect(NfcStationTagPayload.parseRawString('{"v":1}'), isNull);
      expect(
        NfcStationTagPayload.parseRawString(
            '{"v":1,"station_code":"YS-01","tag_id":"","secret":""}'),
        isNull,
      );
    });
  });

  group('StationNfcTag Domain Model', () {
    test('fromJson and toJson round-trip preserves all fields', () {
      final now = DateTime.now().toUtc();
      final tag = StationNfcTag(
        id: 'aaaaaaaa-1111-2222-3333-444444444444',
        stationId: 'bbbbbbbb-1111-2222-3333-444444444444',
        name: 'Main Entrance Tag',
        tagIdentifier: 'ytag_abcd1234efgh',
        isActive: true,
        createdAt: now,
        lastScannedAt: now,
        createdByName: 'Sarah Manager',
      );

      final json = tag.toJson();
      final deserialized = StationNfcTag.fromJson(json);

      expect(deserialized.id, tag.id);
      expect(deserialized.stationId, tag.stationId);
      expect(deserialized.name, 'Main Entrance Tag');
      expect(deserialized.tagIdentifier, 'ytag_abcd1234efgh');
      expect(deserialized.isActive, true);
      expect(deserialized.createdByName, 'Sarah Manager');
    });
  });

  group('AttendanceRecord with NFC Verification', () {
    test('parses NFC verification method and tag references', () {
      final checkInTime = DateTime.parse('2026-09-04T08:00:00Z');
      final checkOutTime = DateTime.parse('2026-09-04T16:30:00Z');

      final record = AttendanceRecord.fromJson({
        'id': 'rec-123',
        'station_id': 'st-456',
        'shift_name': 'Morning Operational',
        'check_in_time': checkInTime.toIso8601String(),
        'check_out_time': checkOutTime.toIso8601String(),
        'worked_minutes': 510,
        'late_minutes': 0,
        'status': 'COMPLETED',
        'verification_method': 'NFC',
        'check_in_nfc_tag_id': 'tag-in-1',
        'check_out_nfc_tag_id': 'tag-out-2',
      });

      expect(record.isOpen, false);
      expect(record.workedMinutes, 510);
      expect(record.status, AttendanceStatus.completed);
      expect(record.verificationMethod, AttendanceVerificationMethod.nfc);
      expect(record.checkInNfcTagId, 'tag-in-1');
      expect(record.checkOutNfcTagId, 'tag-out-2');
    });
  });

  group('MockNfcService contract tests', () {
    test('emits scanned payload when available and configured', () async {
      final mock = MockNfcService();
      const expectedPayload = NfcStationTagPayload(
        version: 1,
        stationCode: 'YS-01',
        tagIdentifier: 'ytag_001',
        rawSecret: 'secret001',
      );
      mock.tagToDiscover = expectedPayload;

      NfcStationTagPayload? scanned;
      await mock.startStationTagScan(
        onTagScanned: (p) => scanned = p,
        onError: (_) {},
      );

      expect(scanned, equals(expectedPayload));
    });

    test('calls onError when device is unavailable', () async {
      final mock = MockNfcService()..isAvailableResult = false;
      String? errorMsg;

      await mock.startStationTagScan(
        onTagScanned: (_) {},
        onError: (err) => errorMsg = err,
      );

      expect(errorMsg, contains('unavailable'));
    });
  });
}
