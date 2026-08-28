import 'availability_period.dart';
import 'availability_submission.dart';

/// KPI Metrics with mathematically verified invariants:
/// eligibleEmployees = submittedEmployees + draftEmployees + notStartedEmployees
/// notSubmittedEmployees = draftEmployees + notStartedEmployees
class AvailabilityKpiMetrics {
  final int eligibleEmployees;
  final int submittedEmployees;
  final int draftEmployees;
  final int notStartedEmployees;
  final int notSubmittedEmployees;

  const AvailabilityKpiMetrics({
    required this.eligibleEmployees,
    required this.submittedEmployees,
    required this.draftEmployees,
    required this.notStartedEmployees,
    required this.notSubmittedEmployees,
  });

  double get submissionRate =>
      eligibleEmployees > 0 ? submittedEmployees / eligibleEmployees : 0.0;

  factory AvailabilityKpiMetrics.fromJson(Map<String, dynamic> json) {
    return AvailabilityKpiMetrics(
      eligibleEmployees: (json['eligible_employees'] as num?)?.toInt() ?? 0,
      submittedEmployees: (json['submitted_employees'] as num?)?.toInt() ?? 0,
      draftEmployees: (json['draft_employees'] as num?)?.toInt() ?? 0,
      notStartedEmployees:
          (json['not_started_employees'] as num?)?.toInt() ?? 0,
      notSubmittedEmployees:
          (json['not_submitted_employees'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Member row in manager availability matrix
class AvailabilityMatrixMember {
  final String membershipId;
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String? employeeCode;
  final AvailabilitySubmissionStatus submissionStatus;
  final DateTime? submittedAt;
  final Map<String, bool> entries;

  const AvailabilityMatrixMember({
    required this.membershipId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.role,
    this.employeeCode,
    required this.submissionStatus,
    this.submittedAt,
    this.entries = const {},
  });

  String get fullName => '$firstName $lastName'.trim().isEmpty
      ? 'Employee'
      : '$firstName $lastName'.trim();

  bool? getSlotState(DateTime date, String periodShiftTemplateId) {
    final key = makeSlotKey(date, periodShiftTemplateId);
    return entries[key];
  }

  factory AvailabilityMatrixMember.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'] as Map<String, dynamic>? ?? {};
    final entriesMap = <String, bool>{};
    entriesRaw.forEach((k, v) {
      if (v is bool) entriesMap[k] = v;
    });

    return AvailabilityMatrixMember(
      membershipId: json['membership_id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'EMPLOYEE',
      employeeCode: json['employee_code'] as String?,
      submissionStatus: AvailabilitySubmissionStatus.fromString(
          json['submission_status'] as String? ?? 'NOT_STARTED'),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      entries: entriesMap,
    );
  }
}

/// Complete Operational Review Matrix for a Period
class AvailabilityMatrix {
  final String periodId;
  final String stationId;
  final AvailabilityKpiMetrics metrics;
  final List<PeriodShiftTemplateSnapshot> templates;
  final List<AvailabilityMatrixMember> members;

  const AvailabilityMatrix({
    required this.periodId,
    required this.stationId,
    required this.metrics,
    required this.templates,
    required this.members,
  });

  factory AvailabilityMatrix.fromJson(Map<String, dynamic> json) {
    final templatesRaw = json['templates'] as List? ?? [];
    final membersRaw = json['members'] as List? ?? [];

    return AvailabilityMatrix(
      periodId: (json['period_id'] ?? '').toString(),
      stationId: (json['station_id'] ?? '').toString(),
      metrics: AvailabilityKpiMetrics.fromJson(
          json['metrics'] as Map<String, dynamic>? ?? {}),
      templates: templatesRaw
          .whereType<Map>()
          .map((t) => PeriodShiftTemplateSnapshot.fromJson(
              Map<String, dynamic>.from(t)))
          .toList(),
      members: membersRaw
          .whereType<Map>()
          .map((m) =>
              AvailabilityMatrixMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
