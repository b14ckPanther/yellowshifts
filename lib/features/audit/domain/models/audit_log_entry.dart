import 'package:flutter/foundation.dart';

@immutable
class AuditLogEntry {
  final String id;
  final String stationId;
  final String? actorId;
  final String actorName;
  final String actorEmail;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.stationId,
    this.actorId,
    required this.actorName,
    required this.actorEmail,
    required this.action,
    required this.targetType,
    this.targetId,
    this.metadata = const {},
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      stationId: json['station_id'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String? ?? 'System',
      actorEmail: json['actor_email'] as String? ?? 'system@internal',
      action: json['action'] as String? ?? 'UNKNOWN_ACTION',
      targetType: json['target_type'] as String? ?? 'UNKNOWN_TARGET',
      targetId: json['target_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class AuditLogQueryResult {
  final List<AuditLogEntry> items;
  final int totalCount;

  const AuditLogQueryResult({
    required this.items,
    required this.totalCount,
  });
}
