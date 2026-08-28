import 'package:flutter/foundation.dart';

@immutable
class QrChallenge {
  final String qrToken;
  final String displayCode;
  final DateTime expiresAt;
  final int ttlSeconds;
  final String stationId;
  final String stationName;
  final DateTime serverTime;

  const QrChallenge({
    required this.qrToken,
    required this.displayCode,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.stationId,
    required this.stationName,
    required this.serverTime,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  double get remainingProgress {
    final now = DateTime.now().toUtc();
    final remainingMs = expiresAt.difference(now).inMilliseconds;
    final totalMs = ttlSeconds * 1000;
    if (totalMs <= 0) return 0.0;
    return (remainingMs / totalMs).clamp(0.0, 1.0);
  }

  factory QrChallenge.fromJson(Map<String, dynamic> json) {
    return QrChallenge(
      qrToken: (json['qr_token'] as String?) ?? '',
      displayCode: (json['display_code'] as String?) ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().toUtc().add(const Duration(seconds: 30)),
      ttlSeconds: (json['ttl_seconds'] as num?)?.toInt() ?? 30,
      stationId: (json['station_id'] as String?) ?? '',
      stationName: (json['station_name'] as String?) ?? '',
      serverTime: json['server_time'] != null
          ? DateTime.parse(json['server_time'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
