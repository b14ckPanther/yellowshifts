class PlatformOverview {
  final int totalStations;
  final int activeStations;
  final int inactiveStations;
  final int activeMemberships;
  final int stationAdminCount;
  final int shiftManagerCount;
  final int nfcTagsTotal;
  final int nfcTagsActive;
  final int staleOpenSessions;
  final int failedExports24h;
  final int pendingNotifications;
  final int operationalAlertCount;
  final String schemaVersion;
  final DateTime telemetryTimestamp;

  const PlatformOverview({
    required this.totalStations,
    required this.activeStations,
    required this.inactiveStations,
    required this.activeMemberships,
    required this.stationAdminCount,
    required this.shiftManagerCount,
    required this.nfcTagsTotal,
    required this.nfcTagsActive,
    required this.staleOpenSessions,
    required this.failedExports24h,
    required this.pendingNotifications,
    required this.operationalAlertCount,
    required this.schemaVersion,
    required this.telemetryTimestamp,
  });

  factory PlatformOverview.fromJson(Map<String, dynamic> json) {
    return PlatformOverview(
      totalStations: (json['total_stations'] as num?)?.toInt() ?? 0,
      activeStations: (json['active_stations'] as num?)?.toInt() ?? 0,
      inactiveStations: (json['inactive_stations'] as num?)?.toInt() ?? 0,
      activeMemberships: (json['active_memberships'] as num?)?.toInt() ?? 0,
      stationAdminCount: (json['station_admin_count'] as num?)?.toInt() ?? 0,
      shiftManagerCount: (json['shift_manager_count'] as num?)?.toInt() ?? 0,
      nfcTagsTotal: (json['nfc_tags_total'] as num?)?.toInt() ?? 0,
      nfcTagsActive: (json['nfc_tags_active'] as num?)?.toInt() ?? 0,
      staleOpenSessions: (json['stale_open_sessions'] as num?)?.toInt() ?? 0,
      failedExports24h: (json['failed_exports_24h'] as num?)?.toInt() ?? 0,
      pendingNotifications:
          (json['pending_notifications'] as num?)?.toInt() ?? 0,
      operationalAlertCount:
          (json['operational_alert_count'] as num?)?.toInt() ?? 0,
      schemaVersion: json['schema_version'] as String? ?? '',
      telemetryTimestamp:
          DateTime.tryParse(json['telemetry_timestamp'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
