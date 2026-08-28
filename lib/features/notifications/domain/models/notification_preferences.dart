import 'package:flutter/foundation.dart';
import 'notification_item.dart';

@immutable
class NotificationCategoryPreference {
  final NotificationCategory category;
  final bool inAppEnabled;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;

  const NotificationCategoryPreference({
    required this.category,
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
  });

  factory NotificationCategoryPreference.fromJson(Map<String, dynamic> json) {
    return NotificationCategoryPreference(
      category: NotificationCategory.fromString(json['category'] as String),
      inAppEnabled: json['in_app_enabled'] as bool? ?? true,
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? false,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
    );
  }

  NotificationCategoryPreference copyWith({
    bool? inAppEnabled,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) {
    return NotificationCategoryPreference(
      category: category,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationCategoryPreference &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          inAppEnabled == other.inAppEnabled &&
          pushEnabled == other.pushEnabled &&
          emailEnabled == other.emailEnabled &&
          smsEnabled == other.smsEnabled;

  @override
  int get hashCode =>
      category.hashCode ^
      inAppEnabled.hashCode ^
      pushEnabled.hashCode ^
      emailEnabled.hashCode ^
      smsEnabled.hashCode;
}

@immutable
class NotificationPreferences {
  final List<NotificationCategoryPreference> preferences;

  const NotificationPreferences({required this.preferences});

  NotificationCategoryPreference? forCategory(NotificationCategory category) {
    for (final pref in preferences) {
      if (pref.category == category) return pref;
    }
    return null;
  }

  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      preferences: NotificationCategory.values
          .map((cat) => NotificationCategoryPreference(
                category: cat,
                inAppEnabled: true,
                pushEnabled: true,
                emailEnabled: false,
                smsEnabled: false,
              ))
          .toList(),
    );
  }

  factory NotificationPreferences.fromJsonList(List<dynamic> list) {
    return NotificationPreferences(
      preferences: list
          .map((item) => NotificationCategoryPreference.fromJson(
              item as Map<String, dynamic>))
          .toList(),
    );
  }
}
