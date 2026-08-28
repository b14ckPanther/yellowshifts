import '../../stations/domain/station_membership.dart';

class EmployeeDetails {
  final String membershipId;
  final String stationId;
  final String userId;
  final StationRole role;
  final MembershipStatus status;
  final String? employeeCode;
  final DateTime joinedAt;
  final String firstName;
  final String lastName;
  final String? phone;
  final String preferredLocale;
  final String? avatarUrl;
  final String? email;

  const EmployeeDetails({
    required this.membershipId,
    required this.stationId,
    required this.userId,
    required this.role,
    required this.status,
    this.employeeCode,
    required this.joinedAt,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.preferredLocale = 'he',
    this.avatarUrl,
    this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final result = '$first$last';
    return result.isNotEmpty ? result : 'U';
  }

  bool get isActive => status == MembershipStatus.active;
  bool get isAdmin => role == StationRole.admin;
  bool get isShiftManager => role == StationRole.shiftManager;
  bool get isEmployee => role == StationRole.employee;

  factory EmployeeDetails.fromJson(Map<String, dynamic> json) {
    return EmployeeDetails(
      membershipId: json['membership_id'] as String,
      stationId: json['station_id'] as String,
      userId: json['user_id'] as String,
      role: StationRole.fromString(json['role'] as String?),
      status: MembershipStatus.fromString(json['status'] as String?),
      employeeCode: json['employee_code'] as String?,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ??
          DateTime.now(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      preferredLocale: json['preferred_locale'] as String? ?? 'he',
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membership_id': membershipId,
      'station_id': stationId,
      'user_id': userId,
      'role': role.value,
      'status': status.value,
      'employee_code': employeeCode,
      'joined_at': joinedAt.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'preferred_locale': preferredLocale,
      'avatar_url': avatarUrl,
      'email': email,
    };
  }

  EmployeeDetails copyWith({
    String? membershipId,
    String? stationId,
    String? userId,
    StationRole? role,
    MembershipStatus? status,
    String? employeeCode,
    DateTime? joinedAt,
    String? firstName,
    String? lastName,
    String? phone,
    String? preferredLocale,
    String? avatarUrl,
    String? email,
  }) {
    return EmployeeDetails(
      membershipId: membershipId ?? this.membershipId,
      stationId: stationId ?? this.stationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      employeeCode: employeeCode ?? this.employeeCode,
      joinedAt: joinedAt ?? this.joinedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeDetails &&
          runtimeType == other.runtimeType &&
          membershipId == other.membershipId &&
          stationId == other.stationId &&
          userId == other.userId &&
          role == other.role &&
          status == other.status &&
          employeeCode == other.employeeCode &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          phone == other.phone &&
          email == other.email;

  @override
  int get hashCode =>
      membershipId.hashCode ^
      stationId.hashCode ^
      userId.hashCode ^
      role.hashCode ^
      status.hashCode ^
      employeeCode.hashCode ^
      firstName.hashCode ^
      lastName.hashCode ^
      phone.hashCode ^
      email.hashCode;
}
