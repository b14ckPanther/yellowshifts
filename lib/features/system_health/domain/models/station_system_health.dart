import 'package:flutter/foundation.dart';

@immutable
class StationSystemHealth {
  final String stationId;
  final int nfcTagsTotal;
  final int nfcTagsActive;
  final int exportsTotal24h;
  final int exportsFailed24h;
  final int staleOpenSessions;
  final DateTime serverTime;

  const StationSystemHealth({
    required this.stationId,
    required this.nfcTagsTotal,
    required this.nfcTagsActive,
    required this.exportsTotal24h,
    required this.exportsFailed24h,
    required this.staleOpenSessions,
    required this.serverTime,
  });

  bool get hasAnomalies => exportsFailed24h > 0 || staleOpenSessions > 0;

  factory StationSystemHealth.fromJson(Map<String, dynamic> json) {
    final nfcTags = (json['nfc_tags'] as Map<String, dynamic>?) ?? {};
    final exports = (json['exports'] as Map<String, dynamic>?) ?? {};
    final exports24h = (json['exports_24h'] as Map<String, dynamic>?) ?? {};
    final anomalies = (json['anomalies'] as Map<String, dynamic>?) ?? {};
    final attendance = (json['attendance'] as Map<String, dynamic>?) ?? {};

    return StationSystemHealth(
      stationId: json['station_id'] as String? ?? '',
      nfcTagsTotal: (nfcTags['total'] as num?)?.toInt() ??
          (json['nfc_tags_total'] as num?)?.toInt() ??
          0,
      nfcTagsActive: (nfcTags['active'] as num?)?.toInt() ??
          (json['nfc_tags_active'] as num?)?.toInt() ??
          0,
      exportsTotal24h: (exports['total_24h'] as num?)?.toInt() ??
          (exports24h['total'] as num?)?.toInt() ??
          0,
      exportsFailed24h: (exports['failed_24h'] as num?)?.toInt() ??
          (exports24h['failed'] as num?)?.toInt() ??
          0,
      staleOpenSessions: (anomalies['stale_open_sessions'] as num?)?.toInt() ??
          (attendance['stale_open_sessions_16h'] as num?)?.toInt() ??
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
