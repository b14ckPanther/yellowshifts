import 'package:flutter/foundation.dart';

@immutable
class ScheduleValidationError {
  final String code;
  final String message;
  final String? shiftId;
  final String? assignmentId;

  const ScheduleValidationError({
    required this.code,
    required this.message,
    this.shiftId,
    this.assignmentId,
  });

  factory ScheduleValidationError.fromJson(Map<String, dynamic> json) {
    return ScheduleValidationError(
      code: json['code'] as String? ?? 'ERROR',
      message: json['message'] as String? ?? '',
      shiftId: json['shift_id'] as String?,
      assignmentId: json['assignment_id'] as String?,
    );
  }
}

@immutable
class ScheduleStaffingSummary {
  final int totalShifts;
  final int fullyStaffedShifts;
  final int understaffedShifts;
  final int overstaffedShifts;
  final int totalAssignments;

  const ScheduleStaffingSummary({
    required this.totalShifts,
    required this.fullyStaffedShifts,
    required this.understaffedShifts,
    required this.overstaffedShifts,
    required this.totalAssignments,
  });

  factory ScheduleStaffingSummary.fromJson(Map<String, dynamic> json) {
    return ScheduleStaffingSummary(
      totalShifts: (json['total_shifts'] as num?)?.toInt() ?? 0,
      fullyStaffedShifts: (json['fully_staffed_shifts'] as num?)?.toInt() ?? 0,
      understaffedShifts: (json['understaffed_shifts'] as num?)?.toInt() ?? 0,
      overstaffedShifts: (json['overstaffed_shifts'] as num?)?.toInt() ?? 0,
      totalAssignments: (json['total_assignments'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class ScheduleValidationResult {
  final String scheduleId;
  final bool isValid;
  final bool canPublish;
  final int hardErrorsCount;
  final int warningsCount;
  final List<ScheduleValidationError> hardErrors;
  final List<ScheduleValidationError> warnings;
  final ScheduleStaffingSummary summary;

  const ScheduleValidationResult({
    required this.scheduleId,
    required this.isValid,
    required this.canPublish,
    required this.hardErrorsCount,
    required this.warningsCount,
    required this.hardErrors,
    required this.warnings,
    required this.summary,
  });

  factory ScheduleValidationResult.fromJson(Map<String, dynamic> json) {
    final errorsJson = json['hard_errors'] as List<dynamic>? ?? [];
    final warningsJson = json['warnings'] as List<dynamic>? ?? [];
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};

    return ScheduleValidationResult(
      scheduleId: json['schedule_id'] as String? ?? '',
      isValid: json['is_valid'] as bool? ?? false,
      canPublish: json['can_publish'] as bool? ?? false,
      hardErrorsCount: (json['hard_errors_count'] as num?)?.toInt() ?? 0,
      warningsCount: (json['warnings_count'] as num?)?.toInt() ?? 0,
      hardErrors: errorsJson
          .map((e) =>
              ScheduleValidationError.fromJson(e as Map<String, dynamic>))
          .toList(),
      warnings: warningsJson
          .map((w) =>
              ScheduleValidationError.fromJson(w as Map<String, dynamic>))
          .toList(),
      summary: ScheduleStaffingSummary.fromJson(summaryJson),
    );
  }
}
