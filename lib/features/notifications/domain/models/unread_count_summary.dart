import 'package:flutter/foundation.dart';

@immutable
class UnreadCountSummary {
  final int unreadCount;
  final int criticalCount;

  const UnreadCountSummary({
    required this.unreadCount,
    required this.criticalCount,
  });

  factory UnreadCountSummary.zero() =>
      const UnreadCountSummary(unreadCount: 0, criticalCount: 0);

  factory UnreadCountSummary.fromJson(Map<String, dynamic> json) {
    return UnreadCountSummary(
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasUnread => unreadCount > 0;
  bool get hasCritical => criticalCount > 0;
}
