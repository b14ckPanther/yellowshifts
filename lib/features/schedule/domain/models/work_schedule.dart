import 'package:flutter/foundation.dart';
import 'work_schedule_shift.dart';

enum WorkScheduleStatus {
  draft,
  published,
  archived;

  static WorkScheduleStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PUBLISHED':
        return WorkScheduleStatus.published;
      case 'ARCHIVED':
        return WorkScheduleStatus.archived;
      case 'DRAFT':
      default:
        return WorkScheduleStatus.draft;
    }
  }

  String get dbValue => name.toUpperCase();
}

@immutable
class WorkSchedule {
  final String id;
  final String stationId;
  final String stationName;
  final String stationTimezone;
  final String availabilityPeriodId;
  final DateTime weekStartDate;
  final WorkScheduleStatus status;
  final int version;
  final String createdBy;
  final String? publishedBy;
  final DateTime? publishedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkScheduleShift> shifts;

  const WorkSchedule({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.stationTimezone,
    required this.availabilityPeriodId,
    required this.weekStartDate,
    required this.status,
    required this.version,
    required this.createdBy,
    this.publishedBy,
    this.publishedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.shifts = const [],
  });

  bool get isDraft => status == WorkScheduleStatus.draft;
  bool get isPublished => status == WorkScheduleStatus.published;
  bool get isArchived => status == WorkScheduleStatus.archived;

  int get totalShiftsCount => shifts.length;
  int get totalAssignmentsCount =>
      shifts.fold(0, (acc, s) => acc + s.assignedStaffCount);

  int get fullyStaffedShiftsCount =>
      shifts.where((s) => s.assignedStaffCount == s.requiredStaffCount).length;

  int get understaffedShiftsCount =>
      shifts.where((s) => s.assignedStaffCount < s.requiredStaffCount).length;

  int get overstaffedShiftsCount =>
      shifts.where((s) => s.assignedStaffCount > s.requiredStaffCount).length;

  double get staffingCoveragePercent {
    if (shifts.isEmpty) return 0.0;
    final totalRequired =
        shifts.fold(0, (acc, s) => acc + s.requiredStaffCount);
    if (totalRequired == 0) return 100.0;
    return (totalAssignmentsCount / totalRequired * 100.0).clamp(0.0, 100.0);
  }

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    final shiftsJson = json['shifts'] as List<dynamic>? ?? [];
    return WorkSchedule(
      id: (json['id'] ?? json['schedule_id'] ?? '').toString(),
      stationId: (json['station_id'] ?? '').toString(),
      stationName: (json['station_name'] ?? '').toString(),
      stationTimezone:
          (json['station_timezone'] ?? 'Asia/Jerusalem').toString(),
      availabilityPeriodId: (json['availability_period_id'] ?? '').toString(),
      weekStartDate: json['week_start_date'] != null
          ? DateTime.parse(json['week_start_date'].toString())
          : DateTime.now(),
      status: WorkScheduleStatus.fromString(json['status']?.toString()),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: (json['created_by'] ?? '').toString(),
      publishedBy: json['published_by']?.toString(),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'].toString())
          : null,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      shifts: shiftsJson
          .whereType<Map>()
          .map((s) => WorkScheduleShift.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}
