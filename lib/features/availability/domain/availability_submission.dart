enum AvailabilitySubmissionStatus {
  notStarted,
  draft,
  submitted;

  static AvailabilitySubmissionStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'SUBMITTED':
        return AvailabilitySubmissionStatus.submitted;
      case 'DRAFT':
        return AvailabilitySubmissionStatus.draft;
      case 'NOT_STARTED':
      default:
        return AvailabilitySubmissionStatus.notStarted;
    }
  }

  String toDbValue() => name.toUpperCase();
}

/// Slot key helper: `${date_YYYY-MM-DD}_${period_shift_template_id}`
String makeSlotKey(DateTime date, String periodShiftTemplateId) {
  final dStr =
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return '${dStr}_$periodShiftTemplateId';
}

/// Domain entity for Employee Availability Submission
class EmployeeAvailabilitySubmission {
  final String periodId;
  final String stationId;
  final DateTime weekStartDate;
  final String periodStatus;
  final DateTime submissionDeadline;
  final String? notes;
  final String? submissionId;
  final AvailabilitySubmissionStatus submissionStatus;
  final DateTime? submittedAt;
  final Map<String, bool>
      entries; // key: makeSlotKey(date, templateId) -> value: isAvailable

  const EmployeeAvailabilitySubmission({
    required this.periodId,
    required this.stationId,
    required this.weekStartDate,
    required this.periodStatus,
    required this.submissionDeadline,
    this.notes,
    this.submissionId,
    required this.submissionStatus,
    this.submittedAt,
    this.entries = const {},
  });

  bool get isSubmitted =>
      submissionStatus == AvailabilitySubmissionStatus.submitted;
  bool get isDraft => submissionStatus == AvailabilitySubmissionStatus.draft;
  bool get isNotStarted =>
      submissionStatus == AvailabilitySubmissionStatus.notStarted;

  /// Returns 3-state availability for a specific slot: true (available), false (unavailable), null (unanswered).
  bool? getSlotState(DateTime date, String periodShiftTemplateId) {
    final key = makeSlotKey(date, periodShiftTemplateId);
    return entries[key];
  }

  int get answeredCount => entries.length;

  factory EmployeeAvailabilitySubmission.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'] as Map<String, dynamic>? ?? {};
    final entriesMap = <String, bool>{};
    entriesRaw.forEach((k, v) {
      if (v is bool) {
        entriesMap[k] = v;
      }
    });

    return EmployeeAvailabilitySubmission(
      periodId: (json['period_id'] ?? '').toString(),
      stationId: (json['station_id'] ?? '').toString(),
      weekStartDate: json['week_start_date'] != null
          ? DateTime.parse(json['week_start_date'].toString())
          : DateTime.now(),
      periodStatus: (json['period_status'] ?? 'DRAFT').toString(),
      submissionDeadline: json['submission_deadline'] != null
          ? DateTime.parse(json['submission_deadline'].toString())
          : DateTime.now().add(const Duration(days: 5)),
      notes: json['notes']?.toString(),
      submissionId: json['submission_id']?.toString(),
      submissionStatus: AvailabilitySubmissionStatus.fromString(
          (json['submission_status'] ?? 'NOT_STARTED').toString()),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'].toString())
          : null,
      entries: entriesMap,
    );
  }
}
