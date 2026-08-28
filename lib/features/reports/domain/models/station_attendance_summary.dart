class StationAttendanceSummary {
  final bool success;
  final String stationId;
  final String stationName;
  final String fromDate;
  final String toDate;
  final int totalWorkedMinutes;
  final int completedShifts;
  final int lateShifts;
  final int totalLateMinutes;
  final int correctedRecords;
  final int openSessions;
  final int employeesWithAttendanceCount;
  final int activeEmployeesCount;
  final int repeatedLatenessEmployeeCount;

  const StationAttendanceSummary({
    required this.success,
    required this.stationId,
    required this.stationName,
    required this.fromDate,
    required this.toDate,
    required this.totalWorkedMinutes,
    required this.completedShifts,
    required this.lateShifts,
    required this.totalLateMinutes,
    required this.correctedRecords,
    required this.openSessions,
    required this.employeesWithAttendanceCount,
    required this.activeEmployeesCount,
    required this.repeatedLatenessEmployeeCount,
  });

  double get totalWorkedHours => totalWorkedMinutes / 60.0;
  double get totalLateHours => totalLateMinutes / 60.0;
  double get averageShiftHours =>
      completedShifts > 0 ? (totalWorkedMinutes / completedShifts) / 60.0 : 0.0;
  double get onTimePercentage => completedShifts > 0
      ? ((completedShifts - lateShifts) / completedShifts) * 100.0
      : 100.0;

  factory StationAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return StationAttendanceSummary(
      success: json['success'] as bool? ?? false,
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      totalWorkedMinutes: (json['total_worked_minutes'] as num?)?.toInt() ?? 0,
      completedShifts: (json['completed_shifts'] as num?)?.toInt() ?? 0,
      lateShifts: (json['late_shifts'] as num?)?.toInt() ?? 0,
      totalLateMinutes: (json['total_late_minutes'] as num?)?.toInt() ?? 0,
      correctedRecords: (json['corrected_records'] as num?)?.toInt() ?? 0,
      openSessions: (json['open_sessions'] as num?)?.toInt() ?? 0,
      employeesWithAttendanceCount:
          (json['employees_with_attendance_count'] as num?)?.toInt() ?? 0,
      activeEmployeesCount:
          (json['active_employees_count'] as num?)?.toInt() ?? 0,
      repeatedLatenessEmployeeCount:
          (json['repeated_lateness_employee_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory StationAttendanceSummary.empty() => const StationAttendanceSummary(
        success: true,
        stationId: '',
        stationName: '',
        fromDate: '',
        toDate: '',
        totalWorkedMinutes: 0,
        completedShifts: 0,
        lateShifts: 0,
        totalLateMinutes: 0,
        correctedRecords: 0,
        openSessions: 0,
        employeesWithAttendanceCount: 0,
        activeEmployeesCount: 0,
        repeatedLatenessEmployeeCount: 0,
      );
}
