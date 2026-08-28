enum IdentityVerificationResult {
  verified,
  notVerified,
  inconclusive;

  static IdentityVerificationResult fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'VERIFIED':
        return IdentityVerificationResult.verified;
      case 'NOT_VERIFIED':
        return IdentityVerificationResult.notVerified;
      case 'INCONCLUSIVE':
      default:
        return IdentityVerificationResult.inconclusive;
    }
  }
}

enum FailureCategory {
  faceMismatch,
  livenessFailed,
  cameraUnavailable,
  providerUnavailable,
  profileNotEnrolled,
  profileRevoked,
  sessionExpired,
  userCancelled,
  inconclusive;

  static FailureCategory fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FACE_MISMATCH':
        return FailureCategory.faceMismatch;
      case 'LIVENESS_FAILED':
        return FailureCategory.livenessFailed;
      case 'CAMERA_UNAVAILABLE':
        return FailureCategory.cameraUnavailable;
      case 'PROVIDER_UNAVAILABLE':
        return FailureCategory.providerUnavailable;
      case 'PROFILE_NOT_ENROLLED':
        return FailureCategory.profileNotEnrolled;
      case 'PROFILE_REVOKED':
        return FailureCategory.profileRevoked;
      case 'SESSION_EXPIRED':
        return FailureCategory.sessionExpired;
      case 'USER_CANCELLED':
        return FailureCategory.userCancelled;
      case 'INCONCLUSIVE':
      default:
        return FailureCategory.inconclusive;
    }
  }

  String toDbValue() {
    switch (this) {
      case FailureCategory.faceMismatch:
        return 'FACE_MISMATCH';
      case FailureCategory.livenessFailed:
        return 'LIVENESS_FAILED';
      case FailureCategory.cameraUnavailable:
        return 'CAMERA_UNAVAILABLE';
      case FailureCategory.providerUnavailable:
        return 'PROVIDER_UNAVAILABLE';
      case FailureCategory.profileNotEnrolled:
        return 'PROFILE_NOT_ENROLLED';
      case FailureCategory.profileRevoked:
        return 'PROFILE_REVOKED';
      case FailureCategory.sessionExpired:
        return 'SESSION_EXPIRED';
      case FailureCategory.userCancelled:
        return 'USER_CANCELLED';
      case FailureCategory.inconclusive:
        return 'INCONCLUSIVE';
    }
  }
}

class IdentityVerificationSessionInit {
  final String attemptId;
  final String providerSessionId;
  final String stationId;
  final String action;
  final String presenceProofId;

  const IdentityVerificationSessionInit({
    required this.attemptId,
    required this.providerSessionId,
    required this.stationId,
    required this.action,
    required this.presenceProofId,
  });

  factory IdentityVerificationSessionInit.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationSessionInit(
      attemptId: json['attempt_id'] as String,
      providerSessionId: json['provider_session_id'] as String,
      stationId: json['station_id'] as String,
      action: json['action'] as String,
      presenceProofId: json['presence_proof_id'] as String,
    );
  }
}
