import 'package:flutter/foundation.dart';

@immutable
class StationSystemHealth {
  final String stationId;
  final int kiosksTotal;
  final int kiosksOnline;
  final int kiosksOffline;
  final int exportsTotal24h;
  final int exportsFailed24h;
  final int staleOpenSessions;
  final int failedIdentityAttempts;
  final DateTime serverTime;

  const StationSystemHealth({
    required this.stationId,
    required this.kiosksTotal,
    required this.kiosksOnline,
    required this.kiosksOffline,
    required this.exportsTotal24h,
    required this.exportsFailed24h,
    required this.staleOpenSessions,
    required this.failedIdentityAttempts,
    required this.serverTime,
  });

  bool get hasAnomalies =>
      kiosksOffline > 0 ||
      exportsFailed24h > 0 ||
      staleOpenSessions > 0 ||
      failedIdentityAttempts > 5;

  factory StationSystemHealth.fromJson(Map<String, dynamic> json) {
    final kiosks = (json['kiosks'] as Map<String, dynamic>?) ?? {};
    final exports = (json['exports'] as Map<String, dynamic>?) ?? {};
    final exports24h = (json['exports_24h'] as Map<String, dynamic>?) ?? {};
    final anomalies = (json['anomalies'] as Map<String, dynamic>?) ?? {};
    final attendance = (json['attendance'] as Map<String, dynamic>?) ?? {};
    final identity = (json['identity'] as Map<String, dynamic>?) ?? {};

    return StationSystemHealth(
      stationId: json['station_id'] as String? ?? '',
      kiosksTotal: (kiosks['total'] as num?)?.toInt() ?? 0,
      kiosksOnline: (kiosks['online'] as num?)?.toInt() ?? 0,
      kiosksOffline: (kiosks['offline'] as num?)?.toInt() ?? 0,
      exportsTotal24h: (exports['total_24h'] as num?)?.toInt() ??
          (exports24h['total'] as num?)?.toInt() ??
          0,
      exportsFailed24h: (exports['failed_24h'] as num?)?.toInt() ??
          (exports24h['failed'] as num?)?.toInt() ??
          0,
      staleOpenSessions: (anomalies['stale_open_sessions'] as num?)?.toInt() ??
          (attendance['stale_open_sessions_16h'] as num?)?.toInt() ??
          0,
      failedIdentityAttempts:
          (anomalies['failed_identity_attempts'] as num?)?.toInt() ??
              (identity['failures_24h'] as num?)?.toInt() ??
              0,
      serverTime: DateTime.tryParse(
            json['server_time'] as String? ??
                json['telemetry_timestamp'] as String? ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}
