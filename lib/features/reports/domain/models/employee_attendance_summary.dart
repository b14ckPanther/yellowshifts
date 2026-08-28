class EmployeeAttendanceSummary {
  final String employeeUserId;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String membershipStatus;
  final String stationRole;
  final int totalWorkedMinutes;
  final int completedShifts;
  final int lateShifts;
  final int totalLateMinutes;
  final int correctedRecords;
  final int openSessionCount;
  final bool hasRepeatedLateness;
  final String? firstShiftDate;
  final String? lastShiftDate;

  const EmployeeAttendanceSummary({
    required this.employeeUserId,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    required this.membershipStatus,
    required this.stationRole,
    required this.totalWorkedMinutes,
    required this.completedShifts,
    required this.lateShifts,
    required this.totalLateMinutes,
    required this.correctedRecords,
    required this.openSessionCount,
    required this.hasRepeatedLateness,
    this.firstShiftDate,
    this.lastShiftDate,
  });

  String get fullName => '$firstName $lastName'.trim();
  double get totalWorkedHours => totalWorkedMinutes / 60.0;
  double get totalLateHours => totalLateMinutes / 60.0;
  bool get isInactive => membershipStatus == 'INACTIVE';

  factory EmployeeAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendanceSummary(
      employeeUserId: json['employee_user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      membershipStatus: json['membership_status'] as String? ?? 'ACTIVE',
      stationRole: json['station_role'] as String? ?? 'EMPLOYEE',
      totalWorkedMinutes: (json['total_worked_minutes'] as num?)?.toInt() ?? 0,
      completedShifts: (json['completed_shifts'] as num?)?.toInt() ?? 0,
      lateShifts: (json['late_shifts'] as num?)?.toInt() ?? 0,
      totalLateMinutes: (json['total_late_minutes'] as num?)?.toInt() ?? 0,
      correctedRecords: (json['corrected_records'] as num?)?.toInt() ?? 0,
      openSessionCount: (json['open_session_count'] as num?)?.toInt() ?? 0,
      hasRepeatedLateness: json['has_repeated_lateness'] as bool? ?? false,
      firstShiftDate: json['first_shift_date'] as String?,
      lastShiftDate: json['last_shift_date'] as String?,
    );
  }
}
