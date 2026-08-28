class PlatformStationSummary {
  final String id;
  final String name;
  final String code;
  final String timezone;
  final String locale;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int activeMembers;
  final int adminCount;
  final int shiftManagerCount;
  final int employeeCount;
  final int kiosksTotal;
  final int kiosksOnline;
  final int kiosksOffline;
  final int staleOpenSessions;
  final int exportsFailed24h;

  const PlatformStationSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.timezone,
    required this.locale,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.activeMembers,
    required this.adminCount,
    required this.shiftManagerCount,
    required this.employeeCount,
    required this.kiosksTotal,
    required this.kiosksOnline,
    required this.kiosksOffline,
    required this.staleOpenSessions,
    required this.exportsFailed24h,
  });

  factory PlatformStationSummary.fromJson(Map<String, dynamic> json) {
    return PlatformStationSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Jerusalem',
      locale: json['locale'] as String? ?? 'he',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      activeMembers: (json['active_members'] as num?)?.toInt() ?? 0,
      adminCount: (json['admin_count'] as num?)?.toInt() ?? 0,
      shiftManagerCount: (json['shift_manager_count'] as num?)?.toInt() ?? 0,
      employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      kiosksTotal: (json['kiosks_total'] as num?)?.toInt() ?? 0,
      kiosksOnline: (json['kiosks_online'] as num?)?.toInt() ?? 0,
      kiosksOffline: (json['kiosks_offline'] as num?)?.toInt() ?? 0,
      staleOpenSessions: (json['stale_open_sessions'] as num?)?.toInt() ?? 0,
      exportsFailed24h: (json['exports_failed_24h'] as num?)?.toInt() ?? 0,
    );
  }

  int get operationalAlertCount =>
      (kiosksOffline > 0 ? 1 : 0) +
      (staleOpenSessions > 0 ? 1 : 0) +
      (exportsFailed24h > 0 ? 1 : 0) +
      (isActive ? 0 : 1);
}
