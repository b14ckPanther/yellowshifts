enum EnrollmentSessionStatus {
  pending,
  completed,
  expired,
  cancelled,
  failed;

  static EnrollmentSessionStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'COMPLETED':
        return EnrollmentSessionStatus.completed;
      case 'EXPIRED':
        return EnrollmentSessionStatus.expired;
      case 'CANCELLED':
        return EnrollmentSessionStatus.cancelled;
      case 'FAILED':
        return EnrollmentSessionStatus.failed;
      case 'PENDING':
      default:
        return EnrollmentSessionStatus.pending;
    }
  }
}

class IdentityEnrollmentSession {
  final String sessionId;
  final String providerSessionId;
  final String provider;
  final String noticeVersion;
  final DateTime expiresAt;

  const IdentityEnrollmentSession({
    required this.sessionId,
    required this.providerSessionId,
    required this.provider,
    required this.noticeVersion,
    required this.expiresAt,
  });

  factory IdentityEnrollmentSession.fromJson(Map<String, dynamic> json) {
    return IdentityEnrollmentSession(
      sessionId: json['session_id'] as String,
      providerSessionId: json['provider_session_id'] as String,
      provider: json['provider'] as String,
      noticeVersion: json['notice_version'] as String? ?? 'v1.0',
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
    );
  }
}
