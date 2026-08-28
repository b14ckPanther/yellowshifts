import 'package:flutter/foundation.dart';

@immutable
class MyShift {
  final String assignmentId;
  final String shiftId;
  final String stationId;
  final String stationName;
  final DateTime operationalDate;
  final String shiftName;
  final String? shiftCode;
  final String startTime;
  final String endTime;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isCrossMidnight;
  final String availabilityStateSnapshot;
  final bool availabilityOverride;

  const MyShift({
    required this.assignmentId,
    required this.shiftId,
    required this.stationId,
    required this.stationName,
    required this.operationalDate,
    required this.shiftName,
    this.shiftCode,
    required this.startTime,
    required this.endTime,
    required this.startsAt,
    required this.endsAt,
    required this.isCrossMidnight,
    required this.availabilityStateSnapshot,
    required this.availabilityOverride,
  });

  Duration get plannedDuration => endsAt.difference(startsAt);

  factory MyShift.fromJson(Map<String, dynamic> json) {
    return MyShift(
      assignmentId: json['assignment_id'] as String? ?? '',
      shiftId: json['shift_id'] as String? ?? '',
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      operationalDate: json['operational_date'] != null
          ? DateTime.parse(json['operational_date'] as String)
          : DateTime.now(),
      shiftName: json['shift_name'] as String? ?? '',
      shiftCode: json['shift_code'] as String?,
      startTime: json['start_time'] as String? ?? '00:00',
      endTime: json['end_time'] as String? ?? '00:00',
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : DateTime.now(),
      isCrossMidnight: json['is_cross_midnight'] as bool? ?? false,
      availabilityStateSnapshot:
          json['availability_state_snapshot'] as String? ?? 'AVAILABLE',
      availabilityOverride: json['availability_override'] as bool? ?? false,
    );
  }
}

@immutable
class MyShiftsResponse {
  final bool hasPublishedSchedule;
  final String? scheduleId;
  final String stationId;
  final String? stationName;
  final DateTime weekStartDate;
  final DateTime? publishedAt;
  final List<MyShift> shifts;

  const MyShiftsResponse({
    required this.hasPublishedSchedule,
    this.scheduleId,
    required this.stationId,
    this.stationName,
    required this.weekStartDate,
    this.publishedAt,
    this.shifts = const [],
  });

  factory MyShiftsResponse.fromJson(Map<String, dynamic> json) {
    final shiftsJson = json['shifts'] as List<dynamic>? ?? [];
    return MyShiftsResponse(
      hasPublishedSchedule: json['has_published_schedule'] as bool? ?? false,
      scheduleId: json['schedule_id'] as String?,
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String?,
      weekStartDate: json['week_start_date'] != null
          ? DateTime.parse(json['week_start_date'] as String)
          : DateTime.now(),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      shifts: shiftsJson
          .map((s) => MyShift.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
