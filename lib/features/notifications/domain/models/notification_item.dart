import 'package:flutter/foundation.dart';

enum NotificationCategory {
  schedule,
  attendance,
  availability,
  operations,
  system;

  static NotificationCategory fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SCHEDULE':
        return NotificationCategory.schedule;
      case 'ATTENDANCE':
        return NotificationCategory.attendance;
      case 'AVAILABILITY':
        return NotificationCategory.availability;
      case 'OPERATIONS':
        return NotificationCategory.operations;
      case 'SYSTEM':
      default:
        return NotificationCategory.system;
    }
  }

  String toDbValue() => name.toUpperCase();
}

enum NotificationPriority {
  low,
  normal,
  high,
  critical;

  static NotificationPriority fromString(String value) {
    switch (value.toUpperCase()) {
      case 'LOW':
        return NotificationPriority.low;
      case 'NORMAL':
        return NotificationPriority.normal;
      case 'HIGH':
        return NotificationPriority.high;
      case 'CRITICAL':
        return NotificationPriority.critical;
      default:
        return NotificationPriority.normal;
    }
  }

  String toDbValue() => name.toUpperCase();
}

@immutable
class NotificationItem {
  final String id;
  final String? stationId;
  final NotificationCategory category;
  final String eventType;
  final NotificationPriority priority;
  final String titleKey;
  final String bodyKey;
  final Map<String, dynamic> renderData;
  final String? actionType;
  final Map<String, dynamic> actionData;
  final bool isMandatory;
  final DateTime? readAt;
  final DateTime? seenAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    this.stationId,
    required this.category,
    required this.eventType,
    required this.priority,
    required this.titleKey,
    required this.bodyKey,
    required this.renderData,
    this.actionType,
    required this.actionData,
    required this.isMandatory,
    this.readAt,
    this.seenAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;
  bool get isCritical => priority == NotificationPriority.critical;
  bool get isHighPriority =>
      priority == NotificationPriority.high || isCritical;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      stationId: json['station_id'] as String?,
      category: NotificationCategory.fromString(
          json['category'] as String? ?? 'SYSTEM'),
      eventType: json['event_type'] as String? ?? 'UNKNOWN',
      priority: NotificationPriority.fromString(
          json['priority'] as String? ?? 'NORMAL'),
      titleKey: json['title_key'] as String? ?? 'notif_generic_title',
      bodyKey: json['body_key'] as String? ?? 'notif_generic_body',
      renderData: (json['render_data'] is Map)
          ? Map<String, dynamic>.from(json['render_data'] as Map)
          : {},
      actionType: json['action_type'] as String?,
      actionData: (json['action_data'] is Map)
          ? Map<String, dynamic>.from(json['action_data'] as Map)
          : {},
      isMandatory: json['is_mandatory'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      seenAt: json['seen_at'] != null
          ? DateTime.tryParse(json['seen_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationItem copyWith({
    DateTime? readAt,
    DateTime? seenAt,
  }) {
    return NotificationItem(
      id: id,
      stationId: stationId,
      category: category,
      eventType: eventType,
      priority: priority,
      titleKey: titleKey,
      bodyKey: bodyKey,
      renderData: renderData,
      actionType: actionType,
      actionData: actionData,
      isMandatory: isMandatory,
      readAt: readAt ?? this.readAt,
      seenAt: seenAt ?? this.seenAt,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          readAt == other.readAt;

  @override
  int get hashCode => id.hashCode ^ readAt.hashCode;
}
