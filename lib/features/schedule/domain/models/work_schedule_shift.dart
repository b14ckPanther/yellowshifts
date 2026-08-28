import 'package:flutter/foundation.dart';
import 'shift_assignment.dart';

enum StaffingState {
  understaffed,
  fullyStaffed,
  overstaffed;

  static StaffingState derive(int assigned, int required) {
    if (assigned < required) return StaffingState.understaffed;
    if (assigned > required) return StaffingState.overstaffed;
    return StaffingState.fullyStaffed;
  }
}

@immutable
class WorkScheduleShift {
  final String id;
  final String workScheduleId;
  final String stationId;
  final DateTime operationalDate;
  final String periodShiftTemplateId;
  final String shiftName;
  final String? shiftCode;
  final String startTime;
  final String endTime;
  final DateTime startsAt;
  final DateTime endsAt;
  final int requiredStaffCount;
  final int assignedStaffCount;
  final int sortOrder;
  final List<ShiftAssignment> assignments;

  const WorkScheduleShift({
    required this.id,
    required this.workScheduleId,
    required this.stationId,
    required this.operationalDate,
    required this.periodShiftTemplateId,
    required this.shiftName,
    this.shiftCode,
    required this.startTime,
    required this.endTime,
    required this.startsAt,
    required this.endsAt,
    required this.requiredStaffCount,
    required this.assignedStaffCount,
    required this.sortOrder,
    this.assignments = const [],
  });

  StaffingState get staffingState =>
      StaffingState.derive(assignedStaffCount, requiredStaffCount);

  bool get isCrossMidnight => startsAt.day != endsAt.day;

  Duration get plannedDuration => endsAt.difference(startsAt);

  factory WorkScheduleShift.fromJson(Map<String, dynamic> json) {
    final asgnsJson = json['assignments'] as List<dynamic>? ?? [];
    return WorkScheduleShift(
      id: (json['id'] ?? '').toString(),
      workScheduleId: (json['work_schedule_id'] ?? '').toString(),
      stationId: (json['station_id'] ?? '').toString(),
      operationalDate: json['operational_date'] != null
          ? DateTime.parse(json['operational_date'].toString())
          : DateTime.now(),
      periodShiftTemplateId:
          (json['period_shift_template_id'] ?? '').toString(),
      shiftName:
          (json['shift_name'] ?? json['shift_name_snapshot'] ?? '').toString(),
      shiftCode:
          (json['shift_code'] ?? json['shift_code_snapshot'])?.toString(),
      startTime: (json['start_time'] ?? json['start_time_snapshot'] ?? '00:00')
          .toString(),
      endTime:
          (json['end_time'] ?? json['end_time_snapshot'] ?? '00:00').toString(),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'].toString())
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'].toString())
          : DateTime.now(),
      requiredStaffCount: (json['required_staff_count'] as num?)?.toInt() ?? 1,
      assignedStaffCount: (json['assigned_staff_count'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] ?? json['sort_order_snapshot'] as num?)
              ?.toInt() ??
          0,
      assignments: asgnsJson
          .whereType<Map>()
          .map((a) => ShiftAssignment.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }
}
