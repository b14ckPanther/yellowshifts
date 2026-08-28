class DailyShiftAttendanceRecord {
  final String recordId;
  final String userId;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final int? workedMinutes;
  final int lateMinutes;
  final String status;
  final String verificationMethod;
  final bool isCorrected;

  const DailyShiftAttendanceRecord({
    required this.recordId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    required this.checkInTime,
    this.checkOutTime,
    this.workedMinutes,
    required this.lateMinutes,
    required this.status,
    required this.verificationMethod,
    required this.isCorrected,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isOpen => checkOutTime == null;

  factory DailyShiftAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return DailyShiftAttendanceRecord(
      recordId: json['record_id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt(),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'COMPLETED',
      verificationMethod: json['verification_method'] as String? ?? 'KIOSK_QR',
      isCorrected: json['is_corrected'] as bool? ?? false,
    );
  }
}

class DailyScheduledShift {
  final String shiftId;
  final String shiftName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int requiredStaffCount;
  final int assignedCount;
  final int checkedInCount;
  final int completedCount;
  final int lateCount;
  final int openCount;
  final List<DailyShiftAttendanceRecord> attendanceRecords;

  const DailyScheduledShift({
    required this.shiftId,
    required this.shiftName,
    required this.startsAt,
    required this.endsAt,
    required this.requiredStaffCount,
    required this.assignedCount,
    required this.checkedInCount,
    required this.completedCount,
    required this.lateCount,
    required this.openCount,
    required this.attendanceRecords,
  });

  int get unassignedCount => requiredStaffCount > assignedCount
      ? requiredStaffCount - assignedCount
      : 0;

  factory DailyScheduledShift.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['attendance_records'] as List? ?? [];
    return DailyScheduledShift(
      shiftId: json['shift_id'] as String,
      shiftName: json['shift_name'] as String? ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      requiredStaffCount: (json['required_staff_count'] as num?)?.toInt() ?? 1,
      assignedCount: (json['assigned_count'] as num?)?.toInt() ?? 0,
      checkedInCount: (json['checked_in_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      lateCount: (json['late_count'] as num?)?.toInt() ?? 0,
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      attendanceRecords: rawRecords
          .map((r) => DailyShiftAttendanceRecord.fromJson(
              Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

class DailyAttendanceReport {
  final bool success;
  final String stationId;
  final String stationName;
  final String date;
  final int totalWorkedMinutes;
  final int completedShifts;
  final int lateShifts;
  final int openSessions;
  final int walkInCount;
  final List<DailyScheduledShift> shifts;
  final List<DailyShiftAttendanceRecord> walkIns;

  const DailyAttendanceReport({
    required this.success,
    required this.stationId,
    required this.stationName,
    required this.date,
    required this.totalWorkedMinutes,
    required this.completedShifts,
    required this.lateShifts,
    required this.openSessions,
    required this.walkInCount,
    required this.shifts,
    required this.walkIns,
  });

  double get totalWorkedHours => totalWorkedMinutes / 60.0;

  factory DailyAttendanceReport.fromJson(Map<String, dynamic> json) {
    final summary =
        Map<String, dynamic>.from(json['day_summary'] as Map? ?? {});
    final rawShifts = json['shifts'] as List? ?? [];
    final rawWalkIns = json['walk_ins'] as List? ?? [];

    return DailyAttendanceReport(
      success: json['success'] as bool? ?? false,
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      totalWorkedMinutes:
          (summary['total_worked_minutes'] as num?)?.toInt() ?? 0,
      completedShifts: (summary['completed_shifts'] as num?)?.toInt() ?? 0,
      lateShifts: (summary['late_shifts'] as num?)?.toInt() ?? 0,
      openSessions: (summary['open_sessions'] as num?)?.toInt() ?? 0,
      walkInCount: (summary['walk_in_count'] as num?)?.toInt() ?? 0,
      shifts: rawShifts
          .map((s) =>
              DailyScheduledShift.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      walkIns: rawWalkIns
          .map((w) => DailyShiftAttendanceRecord.fromJson(
              Map<String, dynamic>.from(w as Map)))
          .toList(),
    );
  }

  factory DailyAttendanceReport.empty() => const DailyAttendanceReport(
        success: true,
        stationId: '',
        stationName: '',
        date: '',
        totalWorkedMinutes: 0,
        completedShifts: 0,
        lateShifts: 0,
        openSessions: 0,
        walkInCount: 0,
        shifts: [],
        walkIns: [],
      );
}
