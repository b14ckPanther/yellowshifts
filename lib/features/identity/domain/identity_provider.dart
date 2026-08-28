import 'models/identity_verification_attempt.dart';

class ProviderEnrollmentResult {
  final bool success;
  final String? providerSubjectId;
  final FailureCategory? failureCategory;
  final String? errorMessage;

  const ProviderEnrollmentResult({
    required this.success,
    this.providerSubjectId,
    this.failureCategory,
    this.errorMessage,
  });
}

class ProviderVerificationResult {
  final bool isVerified;
  final FailureCategory? failureCategory;
  final String? errorMessage;

  const ProviderVerificationResult({
    required this.isVerified,
    this.failureCategory,
    this.errorMessage,
  });
}

abstract class IdentityVerificationProvider {
  String get providerIdentifier;
  bool get isAvailable;

  Future<ProviderEnrollmentResult> startAndCompleteEnrollment({
    required String providerSessionId,
  });

  Future<ProviderVerificationResult> performLivenessAndVerification({
    required String providerSessionId,
  });
}

/// Sandbox/Mock Provider for development & testing.
/// Strictly enforces fail-closed behavior if invoked in a production environment.
class SandboxIdentityProvider implements IdentityVerificationProvider {
  final String environment;

  const SandboxIdentityProvider({this.environment = 'development'});

  @override
  String get providerIdentifier => 'SANDBOX_PROVIDER';

  @override
  bool get isAvailable {
    // Fail closed in production: Sandbox is strictly disallowed in production
    if (environment == 'production') {
      return false;
    }
    return true;
  }

  @override
  Future<ProviderEnrollmentResult> startAndCompleteEnrollment({
    required String providerSessionId,
  }) async {
    if (!isAvailable) {
      return const ProviderEnrollmentResult(
        success: false,
        failureCategory: FailureCategory.providerUnavailable,
        errorMessage:
            'Sandbox identity provider is not permitted in production environment (fail-closed).',
      );
    }

    // Simulate fast biometric enrollment token generation
    await Future.delayed(const Duration(milliseconds: 600));
    final opaqueSubjectId =
        'sbx_subj_${DateTime.now().millisecondsSinceEpoch}_${providerSessionId.hashCode.abs()}';

    return ProviderEnrollmentResult(
      success: true,
      providerSubjectId: opaqueSubjectId,
    );
  }

  @override
  Future<ProviderVerificationResult> performLivenessAndVerification({
    required String providerSessionId,
  }) async {
    if (!isAvailable) {
      return const ProviderVerificationResult(
        isVerified: false,
        failureCategory: FailureCategory.providerUnavailable,
        errorMessage:
            'Sandbox identity provider is not permitted in production environment (fail-closed).',
      );
    }

    // Simulate camera liveness check and face matching
    await Future.delayed(const Duration(milliseconds: 800));

    return const ProviderVerificationResult(
      isVerified: true,
    );
  }
}
