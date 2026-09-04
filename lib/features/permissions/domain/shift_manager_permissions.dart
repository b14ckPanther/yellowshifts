/// Station-scoped permissions for Shift Managers
class ShiftManagerPermissions {
  final bool shiftTemplatesManage;
  final bool availabilityPeriodCreate;
  final bool availabilityPeriodOpen;
  final bool availabilityPeriodClose;
  final bool availabilityTeamRead;
  final bool scheduleManage;
  final bool schedulePublish;
  final bool attendanceCorrect;
  final bool attendanceNfcManage;
  final bool reportsTeamRead;
  final bool reportsStationRead;

  const ShiftManagerPermissions({
    this.shiftTemplatesManage = false,
    this.availabilityPeriodCreate = false,
    this.availabilityPeriodOpen = false,
    this.availabilityPeriodClose = false,
    this.availabilityTeamRead = true,
    this.scheduleManage = false,
    this.schedulePublish = false,
    this.attendanceCorrect = false,
    this.attendanceNfcManage = false,
    this.reportsTeamRead = true,
    this.reportsStationRead = true,
  });

  factory ShiftManagerPermissions.fromJson(Map<String, dynamic> json) {
    return ShiftManagerPermissions(
      shiftTemplatesManage: json['shift_templates.manage'] == true,
      availabilityPeriodCreate: json['availability.period.create'] == true,
      availabilityPeriodOpen: json['availability.period.open'] == true,
      availabilityPeriodClose: json['availability.period.close'] == true,
      availabilityTeamRead: json['availability.team.read'] ?? true,
      scheduleManage: json['schedule.manage'] == true,
      schedulePublish: json['schedule.publish'] == true,
      attendanceCorrect: json['attendance.correct'] == true,
      attendanceNfcManage: json['attendance.nfc.manage'] == true,
      reportsTeamRead: json['reports.team.read'] ?? true,
      reportsStationRead: json['reports.station.read'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_templates.manage': shiftTemplatesManage,
      'availability.period.create': availabilityPeriodCreate,
      'availability.period.open': availabilityPeriodOpen,
      'availability.period.close': availabilityPeriodClose,
      'availability.team.read': availabilityTeamRead,
      'schedule.manage': scheduleManage,
      'schedule.publish': schedulePublish,
      'attendance.correct': attendanceCorrect,
      'attendance.nfc.manage': attendanceNfcManage,
      'reports.team.read': reportsTeamRead,
      'reports.station.read': reportsStationRead,
    };
  }

  ShiftManagerPermissions copyWith({
    bool? shiftTemplatesManage,
    bool? availabilityPeriodCreate,
    bool? availabilityPeriodOpen,
    bool? availabilityPeriodClose,
    bool? availabilityTeamRead,
    bool? scheduleManage,
    bool? schedulePublish,
    bool? attendanceCorrect,
    bool? attendanceNfcManage,
    bool? reportsTeamRead,
    bool? reportsStationRead,
  }) {
    return ShiftManagerPermissions(
      shiftTemplatesManage: shiftTemplatesManage ?? this.shiftTemplatesManage,
      availabilityPeriodCreate:
          availabilityPeriodCreate ?? this.availabilityPeriodCreate,
      availabilityPeriodOpen:
          availabilityPeriodOpen ?? this.availabilityPeriodOpen,
      availabilityPeriodClose:
          availabilityPeriodClose ?? this.availabilityPeriodClose,
      availabilityTeamRead: availabilityTeamRead ?? this.availabilityTeamRead,
      scheduleManage: scheduleManage ?? this.scheduleManage,
      schedulePublish: schedulePublish ?? this.schedulePublish,
      attendanceCorrect: attendanceCorrect ?? this.attendanceCorrect,
      attendanceNfcManage: attendanceNfcManage ?? this.attendanceNfcManage,
      reportsTeamRead: reportsTeamRead ?? this.reportsTeamRead,
      reportsStationRead: reportsStationRead ?? this.reportsStationRead,
    );
  }
}
