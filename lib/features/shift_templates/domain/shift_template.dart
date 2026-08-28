import 'package:flutter/material.dart';

/// Domain entity representing a station-defined shift template.
/// Supports arbitrary names, non-zero durations, and cross-midnight periods.
class ShiftTemplate {
  final String id;
  final String stationId;
  final String name;
  final String? code;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShiftTemplate({
    required this.id,
    required this.stationId,
    required this.name,
    this.code,
    required this.startTime,
    required this.endTime,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this shift crosses midnight (e.g. 23:00 -> 07:00).
  bool get isCrossMidnight {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return startMinutes > endMinutes;
  }

  /// Calculates shift duration in hours (handles cross-midnight).
  double get durationHours {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    var endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }
    return (endMinutes - startMinutes) / 60.0;
  }

  /// Formats time range (e.g. "07:00 - 15:30").
  String formatTimeRange() {
    final sH = startTime.hour.toString().padLeft(2, '0');
    final sM = startTime.minute.toString().padLeft(2, '0');
    final eH = endTime.hour.toString().padLeft(2, '0');
    final eM = endTime.minute.toString().padLeft(2, '0');
    return '$sH:$sM – $eH:$eM';
  }

  factory ShiftTemplate.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return ShiftTemplate(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      startTime: parseTime(json['start_time'] as String),
      endTime: parseTime(json['end_time'] as String),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    String formatTime(TimeOfDay t) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
    }

    return {
      'id': id,
      'station_id': stationId,
      'name': name,
      'code': code,
      'start_time': formatTime(startTime),
      'end_time': formatTime(endTime),
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
