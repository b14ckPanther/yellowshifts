class AttendanceCorrectionDetail {
  final String id;
  final String actorUserId;
  final String actorName;
  final DateTime? previousCheckInTime;
  final DateTime? newCheckInTime;
  final DateTime? previousCheckOutTime;
  final DateTime? newCheckOutTime;
  final int? previousWorkedMinutes;
  final int? newWorkedMinutes;
  final String reason;
  final DateTime createdAt;

  const AttendanceCorrectionDetail({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    this.previousCheckInTime,
    this.newCheckInTime,
    this.previousCheckOutTime,
    this.newCheckOutTime,
    this.previousWorkedMinutes,
    this.newWorkedMinutes,
    required this.reason,
    required this.createdAt,
  });

  factory AttendanceCorrectionDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceCorrectionDetail(
      id: json['id'] as String,
      actorUserId: json['actor_user_id'] as String,
      actorName: json['actor_name'] as String? ?? '',
      previousCheckInTime: json['previous_check_in_time'] != null
          ? DateTime.parse(json['previous_check_in_time'] as String)
          : null,
      newCheckInTime: json['new_check_in_time'] != null
          ? DateTime.parse(json['new_check_in_time'] as String)
          : null,
      previousCheckOutTime: json['previous_check_out_time'] != null
          ? DateTime.parse(json['previous_check_out_time'] as String)
          : null,
      newCheckOutTime: json['new_check_out_time'] != null
          ? DateTime.parse(json['new_check_out_time'] as String)
          : null,
      previousWorkedMinutes: (json['previous_worked_minutes'] as num?)?.toInt(),
      newWorkedMinutes: (json['new_worked_minutes'] as num?)?.toInt(),
      reason: json['reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AttendanceRecordWithCorrections {
  final String id;
  final String? workScheduleShiftId;
  final String? shiftNameSnapshot;
  final DateTime? scheduledStartAtSnapshot;
  final DateTime? scheduledEndAtSnapshot;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final int? workedMinutes;
  final int lateMinutes;
  final String status;
  final String verificationMethod;
  final String operationalDate;
  final bool isLate;
  final List<AttendanceCorrectionDetail> corrections;
  final DateTime createdAt;

  const AttendanceRecordWithCorrections({
    required this.id,
    this.workScheduleShiftId,
    this.shiftNameSnapshot,
    this.scheduledStartAtSnapshot,
    this.scheduledEndAtSnapshot,
    required this.checkInTime,
    this.checkOutTime,
    this.workedMinutes,
    required this.lateMinutes,
    required this.status,
    required this.verificationMethod,
    required this.operationalDate,
    required this.isLate,
    required this.corrections,
    required this.createdAt,
  });

  bool get isCorrected => corrections.isNotEmpty;
  double get workedHours => (workedMinutes ?? 0) / 60.0;

  factory AttendanceRecordWithCorrections.fromJson(Map<String, dynamic> json) {
    final rawCorrections = json['corrections'] as List? ?? [];
    return AttendanceRecordWithCorrections(
      id: json['id'] as String,
      workScheduleShiftId: json['work_schedule_shift_id'] as String?,
      shiftNameSnapshot: json['shift_name_snapshot'] as String?,
      scheduledStartAtSnapshot: json['scheduled_start_at_snapshot'] != null
          ? DateTime.parse(json['scheduled_start_at_snapshot'] as String)
          : null,
      scheduledEndAtSnapshot: json['scheduled_end_at_snapshot'] != null
          ? DateTime.parse(json['scheduled_end_at_snapshot'] as String)
          : null,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt(),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'COMPLETED',
      verificationMethod: json['verification_method'] as String? ?? 'KIOSK_QR',
      operationalDate: json['operational_date'] as String? ?? '',
      isLate: json['is_late'] as bool? ?? false,
      corrections: rawCorrections
          .map((c) => AttendanceCorrectionDetail.fromJson(
              Map<String, dynamic>.from(c as Map)))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class StationEmployeeAttendanceDetailResponse {
  final bool success;
  final String stationId;
  final String stationName;
  final EmployeeAttendanceProfile employee;
  final String fromDate;
  final String toDate;
  final Map<String, dynamic> summary;
  final List<AttendanceRecordWithCorrections> records;

  const StationEmployeeAttendanceDetailResponse({
    required this.success,
    required this.stationId,
    required this.stationName,
    required this.employee,
    required this.fromDate,
    required this.toDate,
    required this.summary,
    required this.records,
  });

  factory StationEmployeeAttendanceDetailResponse.fromJson(
      Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? [];
    return StationEmployeeAttendanceDetailResponse(
      success: json['success'] as bool? ?? false,
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      employee: EmployeeAttendanceProfile.fromJson(
          Map<String, dynamic>.from(json['employee'] as Map? ?? {})),
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      records: rawRecords
          .map((r) => AttendanceRecordWithCorrections.fromJson(
              Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

class EmployeeAttendanceProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String membershipStatus;
  final String stationRole;

  const EmployeeAttendanceProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    required this.membershipStatus,
    required this.stationRole,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory EmployeeAttendanceProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendanceProfile(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      membershipStatus: json['membership_status'] as String? ?? 'ACTIVE',
      stationRole: json['station_role'] as String? ?? 'EMPLOYEE',
    );
  }
}
