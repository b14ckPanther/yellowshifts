import 'package:flutter/foundation.dart';

@immutable
class StationNfcTag {
  final String id;
  final String stationId;
  final String name;
  final String tagIdentifier;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final DateTime? lastScannedAt;
  final String? createdByName;
  final String? revokedByName;

  const StationNfcTag({
    required this.id,
    required this.stationId,
    required this.name,
    required this.tagIdentifier,
    required this.isActive,
    required this.createdAt,
    this.revokedAt,
    this.lastScannedAt,
    this.createdByName,
    this.revokedByName,
  });

  factory StationNfcTag.fromJson(Map<String, dynamic> json) {
    return StationNfcTag(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      name: json['name'] as String? ?? '',
      tagIdentifier: json['tag_identifier'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      lastScannedAt: json['last_scanned_at'] != null
          ? DateTime.parse(json['last_scanned_at'] as String)
          : null,
      createdByName: json['created_by_name'] as String?,
      revokedByName: json['revoked_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'name': name,
        'tag_identifier': tagIdentifier,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'revoked_at': revokedAt?.toIso8601String(),
        'last_scanned_at': lastScannedAt?.toIso8601String(),
        'created_by_name': createdByName,
        'revoked_by_name': revokedByName,
      };
}
