import 'package:flutter/foundation.dart';

enum LiveRosterStatus {
  working,
  upcoming,
  late,
  completed,
  notCheckedIn,
  unknown
}

@immutable
class LiveRosterItem {
  final String? shiftId;
  final String shiftName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? assignmentId;
  final String userId;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String? attendanceId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? workedMinutes;
  final int lateMinutes;
  final LiveRosterStatus operationalStatus;
  final int? elapsedMinutes;

  const LiveRosterItem({
    this.shiftId,
    required this.shiftName,
    required this.startsAt,
    required this.endsAt,
    this.assignmentId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    this.attendanceId,
    this.checkInTime,
    this.checkOutTime,
    this.workedMinutes,
    required this.lateMinutes,
    required this.operationalStatus,
    this.elapsedMinutes,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory LiveRosterItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['operational_status'] as String? ?? 'UNKNOWN';
    return LiveRosterItem(
      shiftId: json['shift_id'] as String?,
      shiftName: json['shift_name'] as String? ?? '',
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : DateTime.now().add(const Duration(hours: 8)),
      assignmentId: json['assignment_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      attendanceId: json['attendance_id'] as String?,
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt(),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      operationalStatus: _parseRosterStatus(statusStr),
      elapsedMinutes: (json['elapsed_minutes'] as num?)?.toInt(),
    );
  }

  static LiveRosterStatus _parseRosterStatus(String s) {
    switch (s.toUpperCase()) {
      case 'WORKING':
        return LiveRosterStatus.working;
      case 'UPCOMING':
        return LiveRosterStatus.upcoming;
      case 'LATE':
        return LiveRosterStatus.late;
      case 'COMPLETED':
        return LiveRosterStatus.completed;
      case 'NOT_CHECKED_IN':
        return LiveRosterStatus.notCheckedIn;
      default:
        return LiveRosterStatus.unknown;
    }
  }
}

@immutable
class LiveAttendanceKpis {
  final int currentlyWorking;
  final int scheduledUpcoming;
  final int lateCheckedIn;
  final int completed;
  final int notCheckedIn;

  const LiveAttendanceKpis({
    required this.currentlyWorking,
    required this.scheduledUpcoming,
    required this.lateCheckedIn,
    required this.completed,
    required this.notCheckedIn,
  });

  factory LiveAttendanceKpis.fromJson(Map<String, dynamic> json) {
    return LiveAttendanceKpis(
      currentlyWorking: (json['currently_working'] as num?)?.toInt() ?? 0,
      scheduledUpcoming: (json['scheduled_upcoming'] as num?)?.toInt() ?? 0,
      lateCheckedIn: (json['late_checked_in'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      notCheckedIn: (json['not_checked_in'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class LiveAttendanceResponse {
  final bool success;
  final String stationId;
  final String targetDate;
  final LiveAttendanceKpis kpis;
  final List<LiveRosterItem> roster;

  const LiveAttendanceResponse({
    required this.success,
    required this.stationId,
    required this.targetDate,
    required this.kpis,
    required this.roster,
  });

  factory LiveAttendanceResponse.fromJson(Map<String, dynamic> json) {
    final rosterList = (json['roster'] as List<dynamic>?)
            ?.map((e) => LiveRosterItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return LiveAttendanceResponse(
      success: json['success'] as bool? ?? true,
      stationId: json['station_id'] as String,
      targetDate: json['target_date'] as String,
      kpis: LiveAttendanceKpis.fromJson(
          (json['kpis'] as Map<String, dynamic>?) ?? {}),
      roster: rosterList,
    );
  }
}
