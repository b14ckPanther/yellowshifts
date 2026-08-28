class IdentityVerificationProof {
  final bool success;
  final String? identityProofToken;
  final DateTime? expiresAt;
  final String? action;
  final String? failureCategory;
  final bool isOverride;

  const IdentityVerificationProof({
    required this.success,
    this.identityProofToken,
    this.expiresAt,
    this.action,
    this.failureCategory,
    this.isOverride = false,
  });

  factory IdentityVerificationProof.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationProof(
      success: json['success'] as bool? ?? false,
      identityProofToken: json['identity_proof_token'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
          : null,
      action: json['action'] as String?,
      failureCategory: json['failure_category'] as String?,
      isOverride: json['override_id'] != null,
    );
  }
}
