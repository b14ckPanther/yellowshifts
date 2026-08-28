import 'open_attendance_session.dart';

class AttendanceSummary {
  final bool success;
  final String fromDate;
  final String toDate;
  final String? stationId;
  final int totalWorkedMinutes;
  final int completedShifts;
  final int lateShifts;
  final int totalLateMinutes;
  final int correctedRecords;
  final int openSessionCount;
  final int stationsWorkedCount;
  final String? firstShiftDate;
  final String? lastShiftDate;
  final OpenAttendanceSession? activeOpenSession;

  const AttendanceSummary({
    required this.success,
    required this.fromDate,
    required this.toDate,
    this.stationId,
    required this.totalWorkedMinutes,
    required this.completedShifts,
    required this.lateShifts,
    required this.totalLateMinutes,
    required this.correctedRecords,
    required this.openSessionCount,
    required this.stationsWorkedCount,
    this.firstShiftDate,
    this.lastShiftDate,
    this.activeOpenSession,
  });

  double get totalWorkedHours => totalWorkedMinutes / 60.0;
  double get totalLateHours => totalLateMinutes / 60.0;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      success: json['success'] as bool? ?? false,
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      stationId: json['station_id'] as String?,
      totalWorkedMinutes: (json['total_worked_minutes'] as num?)?.toInt() ?? 0,
      completedShifts: (json['completed_shifts'] as num?)?.toInt() ?? 0,
      lateShifts: (json['late_shifts'] as num?)?.toInt() ?? 0,
      totalLateMinutes: (json['total_late_minutes'] as num?)?.toInt() ?? 0,
      correctedRecords: (json['corrected_records'] as num?)?.toInt() ?? 0,
      openSessionCount: (json['open_session_count'] as num?)?.toInt() ?? 0,
      stationsWorkedCount:
          (json['stations_worked_count'] as num?)?.toInt() ?? 0,
      firstShiftDate: json['first_shift_date'] as String?,
      lastShiftDate: json['last_shift_date'] as String?,
      activeOpenSession: json['active_open_session'] != null
          ? OpenAttendanceSession.fromJson(
              Map<String, dynamic>.from(json['active_open_session'] as Map))
          : null,
    );
  }

  factory AttendanceSummary.empty() => const AttendanceSummary(
        success: true,
        fromDate: '',
        toDate: '',
        totalWorkedMinutes: 0,
        completedShifts: 0,
        lateShifts: 0,
        totalLateMinutes: 0,
        correctedRecords: 0,
        openSessionCount: 0,
        stationsWorkedCount: 0,
      );
}
