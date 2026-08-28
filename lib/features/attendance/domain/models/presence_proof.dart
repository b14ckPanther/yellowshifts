import 'package:flutter/foundation.dart';

enum AttendanceAction { checkIn, checkOut }

@immutable
class PresenceProof {
  final String presenceProofToken;
  final AttendanceAction action;
  final DateTime expiresAt;
  final String stationId;
  final String stationName;
  final Map<String, dynamic>? shiftPreview;

  const PresenceProof({
    required this.presenceProofToken,
    required this.action,
    required this.expiresAt,
    required this.stationId,
    required this.stationName,
    this.shiftPreview,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory PresenceProof.fromJson(Map<String, dynamic> json) {
    final actionStr = json['action'] as String? ?? 'CHECK_IN';
    return PresenceProof(
      presenceProofToken: json['presence_proof_token'] as String,
      action: actionStr == 'CHECK_OUT'
          ? AttendanceAction.checkOut
          : AttendanceAction.checkIn,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String? ?? '',
      shiftPreview: json['shift_preview'] as Map<String, dynamic>?,
    );
  }
}
