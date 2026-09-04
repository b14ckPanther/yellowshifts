import 'package:flutter/foundation.dart';

enum AttendanceStatus { open, completed, corrected }

enum AttendanceVerificationMethod { nfc, manualAdmin }

@immutable
class AttendanceRecord {
  final String id;
  final String stationId;
  final String? shiftName;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final int? workedMinutes;
  final int lateMinutes;
  final AttendanceStatus status;
  final AttendanceVerificationMethod verificationMethod;
  final String? checkInNfcTagId;
  final String? checkOutNfcTagId;

  const AttendanceRecord({
    required this.id,
    required this.stationId,
    this.shiftName,
    this.scheduledStartAt,
    this.scheduledEndAt,
    required this.checkInTime,
    this.checkOutTime,
    this.workedMinutes,
    required this.lateMinutes,
    required this.status,
    required this.verificationMethod,
    this.checkInNfcTagId,
    this.checkOutNfcTagId,
  });

  bool get isOpen => checkOutTime == null;

  int get currentElapsedMinutes {
    if (checkOutTime != null) {
      return workedMinutes ?? 0;
    }
    final now = DateTime.now().toUtc();
    final diff = now.difference(checkInTime);
    return diff.inMinutes >= 0 ? diff.inMinutes : 0;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'OPEN';
    final verStr = json['verification_method'] as String? ?? 'NFC';

    return AttendanceRecord(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      shiftName: (json['shift_name'] ?? json['shift_name_snapshot']) as String?,
      scheduledStartAt:
          (json['scheduled_start_at'] ?? json['scheduled_start_at_snapshot']) !=
                  null
              ? DateTime.parse((json['scheduled_start_at'] ??
                  json['scheduled_start_at_snapshot']) as String)
              : null,
      scheduledEndAt:
          (json['scheduled_end_at'] ?? json['scheduled_end_at_snapshot']) !=
                  null
              ? DateTime.parse((json['scheduled_end_at'] ??
                  json['scheduled_end_at_snapshot']) as String)
              : null,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt(),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      status: _parseStatus(statusStr),
      verificationMethod: _parseVerification(verStr),
      checkInNfcTagId: json['check_in_nfc_tag_id'] as String?,
      checkOutNfcTagId: json['check_out_nfc_tag_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'shift_name': shiftName,
        'scheduled_start_at': scheduledStartAt?.toIso8601String(),
        'scheduled_end_at': scheduledEndAt?.toIso8601String(),
        'check_in_time': checkInTime.toIso8601String(),
        'check_out_time': checkOutTime?.toIso8601String(),
        'worked_minutes': workedMinutes,
        'late_minutes': lateMinutes,
        'status': status.name.toUpperCase(),
        'verification_method':
            verificationMethod == AttendanceVerificationMethod.manualAdmin
                ? 'MANUAL_ADMIN'
                : 'NFC',
        'check_in_nfc_tag_id': checkInNfcTagId,
        'check_out_nfc_tag_id': checkOutNfcTagId,
      };

  static AttendanceStatus _parseStatus(String s) {
    switch (s.toUpperCase()) {
      case 'COMPLETED':
        return AttendanceStatus.completed;
      case 'CORRECTED':
        return AttendanceStatus.corrected;
      case 'OPEN':
      default:
        return AttendanceStatus.open;
    }
  }

  static AttendanceVerificationMethod _parseVerification(String s) {
    switch (s.toUpperCase()) {
      case 'MANUAL_ADMIN':
        return AttendanceVerificationMethod.manualAdmin;
      case 'NFC':
      default:
        return AttendanceVerificationMethod.nfc;
    }
  }
}
