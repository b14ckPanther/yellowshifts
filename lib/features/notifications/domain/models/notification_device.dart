import 'package:flutter/foundation.dart';

@immutable
class NotificationDevice {
  final String id;
  final String platform;
  final String provider;
  final String deviceLabel;
  final bool isActive;
  final DateTime lastSeenAt;
  final DateTime createdAt;
  final DateTime? revokedAt;

  const NotificationDevice({
    required this.id,
    required this.platform,
    required this.provider,
    required this.deviceLabel,
    required this.isActive,
    required this.lastSeenAt,
    required this.createdAt,
    this.revokedAt,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> json) {
    return NotificationDevice(
      id: json['id'] as String,
      platform: json['platform'] as String? ?? 'web',
      provider: json['provider'] as String? ?? 'mock',
      deviceLabel: json['device_label'] as String? ?? 'Device',
      isActive: json['is_active'] as bool? ?? true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
    );
  }
}
