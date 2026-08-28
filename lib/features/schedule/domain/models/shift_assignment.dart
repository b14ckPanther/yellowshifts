import 'package:flutter/foundation.dart';

@immutable
class ShiftAssignment {
  final String id;
  final String membershipId;
  final String userId;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String role;
  final String
      availabilityStateSnapshot; // 'AVAILABLE', 'UNAVAILABLE', 'NOT_SUBMITTED'
  final bool availabilityOverride;
  final String? availabilityOverrideReason;
  final String assignedBy;
  final DateTime createdAt;

  const ShiftAssignment({
    required this.id,
    required this.membershipId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    required this.role,
    required this.availabilityStateSnapshot,
    required this.availabilityOverride,
    this.availabilityOverrideReason,
    required this.assignedBy,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) {
    return ShiftAssignment(
      id: json['id'] as String? ?? '',
      membershipId: json['membership_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String?,
      role: json['role'] as String? ?? 'EMPLOYEE',
      availabilityStateSnapshot:
          json['availability_state_snapshot'] as String? ?? 'NOT_SUBMITTED',
      availabilityOverride: json['availability_override'] as bool? ?? false,
      availabilityOverrideReason:
          json['availability_override_reason'] as String?,
      assignedBy: json['assigned_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
