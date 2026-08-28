enum IdentityProfileStatus {
  notEnrolled,
  pending,
  active,
  revoked,
  failed;

  static IdentityProfileStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
        return IdentityProfileStatus.active;
      case 'PENDING':
        return IdentityProfileStatus.pending;
      case 'REVOKED':
        return IdentityProfileStatus.revoked;
      case 'FAILED':
        return IdentityProfileStatus.failed;
      case 'NOT_ENROLLED':
      default:
        return IdentityProfileStatus.notEnrolled;
    }
  }

  String toDbValue() {
    switch (this) {
      case IdentityProfileStatus.active:
        return 'ACTIVE';
      case IdentityProfileStatus.pending:
        return 'PENDING';
      case IdentityProfileStatus.revoked:
        return 'REVOKED';
      case IdentityProfileStatus.failed:
        return 'FAILED';
      case IdentityProfileStatus.notEnrolled:
        return 'NOT_ENROLLED';
    }
  }

  bool get isEnrolled => this == IdentityProfileStatus.active;
}

class IdentityProfile {
  final bool enrolled;
  final IdentityProfileStatus status;
  final String? provider;
  final String? noticeVersion;
  final DateTime? consentedAt;
  final DateTime? enrolledAt;
  final DateTime? revokedAt;
  final DateTime? lastVerifiedAt;

  const IdentityProfile({
    required this.enrolled,
    required this.status,
    this.provider,
    this.noticeVersion,
    this.consentedAt,
    this.enrolledAt,
    this.revokedAt,
    this.lastVerifiedAt,
  });

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    return IdentityProfile(
      enrolled: json['enrolled'] as bool? ?? false,
      status: IdentityProfileStatus.fromString(json['status'] as String?),
      provider: json['provider'] as String?,
      noticeVersion: json['notice_version'] as String?,
      consentedAt: json['consented_at'] != null
          ? DateTime.tryParse(json['consented_at'] as String)?.toLocal()
          : null,
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.tryParse(json['enrolled_at'] as String)?.toLocal()
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)?.toLocal()
          : null,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'] as String)?.toLocal()
          : null,
    );
  }

  static const notEnrolledProfile = IdentityProfile(
    enrolled: false,
    status: IdentityProfileStatus.notEnrolled,
  );
}

class TeamMemberIdentityStatus {
  final String membershipId;
  final String userId;
  final String? employeeCode;
  final String firstName;
  final String lastName;
  final String role;
  final IdentityProfileStatus identityStatus;
  final DateTime? enrolledAt;
  final DateTime? lastVerifiedAt;

  const TeamMemberIdentityStatus({
    required this.membershipId,
    required this.userId,
    this.employeeCode,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.identityStatus,
    this.enrolledAt,
    this.lastVerifiedAt,
  });

  factory TeamMemberIdentityStatus.fromJson(Map<String, dynamic> json) {
    return TeamMemberIdentityStatus(
      membershipId: json['membership_id'] as String,
      userId: json['user_id'] as String,
      employeeCode: json['employee_code'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String? ?? 'EMPLOYEE',
      identityStatus:
          IdentityProfileStatus.fromString(json['identity_status'] as String?),
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.tryParse(json['enrolled_at'] as String)?.toLocal()
          : null,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'] as String)?.toLocal()
          : null,
    );
  }
}
