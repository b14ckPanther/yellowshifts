class PlatformAuditEntry {
  final String id;
  final String? stationId;
  final String? stationName;
  final String? actorId;
  final String actorName;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const PlatformAuditEntry({
    required this.id,
    this.stationId,
    this.stationName,
    this.actorId,
    required this.actorName,
    required this.action,
    required this.targetType,
    this.targetId,
    required this.metadata,
    required this.createdAt,
  });

  factory PlatformAuditEntry.fromJson(Map<String, dynamic> json) {
    return PlatformAuditEntry(
      id: json['id'] as String,
      stationId: json['station_id'] as String?,
      stationName: json['station_name'] as String?,
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String? ?? 'System',
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PlatformAuditPage {
  final int total;
  final int limit;
  final int offset;
  final List<PlatformAuditEntry> entries;

  const PlatformAuditPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.entries,
  });

  factory PlatformAuditPage.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    return PlatformAuditPage(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      entries: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(PlatformAuditEntry.fromJson)
              .toList()
          : const [],
    );
  }
}
