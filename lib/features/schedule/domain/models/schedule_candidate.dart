import 'package:flutter/foundation.dart';

enum CandidateAvailabilityState {
  available,
  unavailable,
  notSubmitted,
  notEligible;

  static CandidateAvailabilityState fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'AVAILABLE':
        return CandidateAvailabilityState.available;
      case 'UNAVAILABLE':
        return CandidateAvailabilityState.unavailable;
      case 'NOT_SUBMITTED':
      default:
        return CandidateAvailabilityState.notSubmitted;
    }
  }
}

enum CandidateConflictState {
  none,
  overlappingAssignment,
  crossStationOverlap;

  static CandidateConflictState fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'OVERLAPPING_ASSIGNMENT':
        return CandidateConflictState.overlappingAssignment;
      case 'CROSS_STATION_OVERLAP':
        return CandidateConflictState.crossStationOverlap;
      case 'NONE':
      default:
        return CandidateConflictState.none;
    }
  }

  bool get hasConflict => this != CandidateConflictState.none;
}

@immutable
class ScheduleCandidate {
  final String membershipId;
  final String userId;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String role;
  final bool alreadyAssigned;
  final CandidateAvailabilityState availabilityState;
  final CandidateConflictState conflictState;
  final int weeklyShiftsCount;

  const ScheduleCandidate({
    required this.membershipId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    required this.role,
    required this.alreadyAssigned,
    required this.availabilityState,
    required this.conflictState,
    required this.weeklyShiftsCount,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get requiresOverride =>
      availabilityState == CandidateAvailabilityState.unavailable ||
      availabilityState == CandidateAvailabilityState.notSubmitted;

  factory ScheduleCandidate.fromJson(Map<String, dynamic> json) {
    return ScheduleCandidate(
      membershipId: json['membership_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      role: json['role'] as String? ?? 'EMPLOYEE',
      alreadyAssigned: json['already_assigned'] as bool? ?? false,
      availabilityState: CandidateAvailabilityState.fromString(
          json['availability_state'] as String?),
      conflictState:
          CandidateConflictState.fromString(json['conflict_state'] as String?),
      weeklyShiftsCount: (json['weekly_shifts_count'] as num?)?.toInt() ?? 0,
    );
  }
}
