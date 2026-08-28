import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/identity/domain/identity_provider.dart';
import 'package:yellowshifts/features/identity/domain/models/identity_verification_attempt.dart';

void main() {
  group('SandboxIdentityProvider Tests', () {
    test('development environment allows enrollment and verification',
        () async {
      const provider = SandboxIdentityProvider(environment: 'development');
      expect(provider.isAvailable, isTrue);
      expect(provider.providerIdentifier, equals('SANDBOX_PROVIDER'));

      final enrollResult = await provider.startAndCompleteEnrollment(
        providerSessionId: 'sess_123',
      );
      expect(enrollResult.success, isTrue);
      expect(enrollResult.providerSubjectId, isNotNull);
      expect(enrollResult.providerSubjectId, startsWith('sbx_subj_'));

      final verResult = await provider.performLivenessAndVerification(
        providerSessionId: 'sess_123',
      );
      expect(verResult.isVerified, isTrue);
      expect(verResult.failureCategory, isNull);
    });

    test('production environment fails closed (zero silent downgrade)',
        () async {
      const provider = SandboxIdentityProvider(environment: 'production');
      expect(provider.isAvailable, isFalse);

      final enrollResult = await provider.startAndCompleteEnrollment(
        providerSessionId: 'sess_prod_123',
      );
      expect(enrollResult.success, isFalse);
      expect(enrollResult.failureCategory,
          equals(FailureCategory.providerUnavailable));
      expect(enrollResult.errorMessage, contains('fail-closed'));

      final verResult = await provider.performLivenessAndVerification(
        providerSessionId: 'sess_prod_123',
      );
      expect(verResult.isVerified, isFalse);
      expect(verResult.failureCategory,
          equals(FailureCategory.providerUnavailable));
    });
  });
}
