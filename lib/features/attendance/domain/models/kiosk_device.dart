import 'package:flutter/foundation.dart';

@immutable
class KioskDevice {
  final String id;
  final String stationId;
  final String name;
  final String deviceIdentifier;
  final int credentialVersion;
  final bool isActive;
  final DateTime? lastSeenAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KioskDevice({
    required this.id,
    required this.stationId,
    required this.name,
    required this.deviceIdentifier,
    required this.credentialVersion,
    required this.isActive,
    this.lastSeenAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOnline {
    if (lastSeenAt == null) return false;
    final diff = DateTime.now().toUtc().difference(lastSeenAt!);
    return diff.inMinutes <= 3;
  }

  factory KioskDevice.fromJson(Map<String, dynamic> json) {
    return KioskDevice(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      name: json['name'] as String,
      deviceIdentifier: json['device_identifier'] as String,
      credentialVersion: (json['credential_version'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'name': name,
      'device_identifier': deviceIdentifier,
      'credential_version': credentialVersion,
      'is_active': isActive,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
