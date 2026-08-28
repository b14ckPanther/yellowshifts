class AttendanceHistoryItem {
  final String id;
  final String stationId;
  final String stationName;
  final String stationCode;
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
  final bool isCorrected;
  final int correctionCount;
  final DateTime createdAt;

  const AttendanceHistoryItem({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.stationCode,
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
    required this.isCorrected,
    required this.correctionCount,
    required this.createdAt,
  });

  bool get isOpen => checkOutTime == null;
  double get workedHours => (workedMinutes ?? 0) / 60.0;

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItem(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String? ?? '',
      stationCode: json['station_code'] as String? ?? '',
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
      isCorrected: json['is_corrected'] as bool? ?? false,
      correctionCount: (json['correction_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
