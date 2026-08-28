import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/identity/domain/models/identity_policy.dart';
import 'package:yellowshifts/features/identity/domain/models/identity_profile.dart';
import 'package:yellowshifts/features/identity/domain/models/identity_verification_attempt.dart';
import 'package:yellowshifts/features/identity/domain/models/identity_verification_proof.dart';

void main() {
  group('IdentityPolicy Model Tests', () {
    test('IdentityVerificationMode enum parsing and DB value conversions', () {
      expect(IdentityVerificationMode.fromString('DISABLED'),
          equals(IdentityVerificationMode.disabled));
      expect(IdentityVerificationMode.fromString('CHECK_IN_ONLY'),
          equals(IdentityVerificationMode.checkInOnly));
      expect(IdentityVerificationMode.fromString('CHECK_IN_AND_CHECK_OUT'),
          equals(IdentityVerificationMode.checkInAndCheckOut));
      expect(IdentityVerificationMode.fromString(null),
          equals(IdentityVerificationMode.disabled));

      expect(IdentityVerificationMode.disabled.toDbValue(), equals('DISABLED'));
      expect(IdentityVerificationMode.checkInOnly.toDbValue(),
          equals('CHECK_IN_ONLY'));
      expect(IdentityVerificationMode.checkInAndCheckOut.toDbValue(),
          equals('CHECK_IN_AND_CHECK_OUT'));

      expect(IdentityVerificationMode.disabled.isRequiredForCheckIn, isFalse);
      expect(IdentityVerificationMode.disabled.isRequiredForCheckOut, isFalse);
      expect(IdentityVerificationMode.checkInOnly.isRequiredForCheckIn, isTrue);
      expect(
          IdentityVerificationMode.checkInOnly.isRequiredForCheckOut, isFalse);
      expect(IdentityVerificationMode.checkInAndCheckOut.isRequiredForCheckIn,
          isTrue);
      expect(IdentityVerificationMode.checkInAndCheckOut.isRequiredForCheckOut,
          isTrue);
    });
  });

  group('IdentityProfile Model Tests', () {
    test('parses active identity profile correctly', () {
      final json = {
        'enrolled': true,
        'status': 'ACTIVE',
        'provider': 'SANDBOX_PROVIDER',
        'notice_version': 'v1.0',
        'consented_at': '2026-08-26T00:00:00.000Z',
        'enrolled_at': '2026-08-26T00:05:00.000Z',
        'last_verified_at': '2026-08-26T01:00:00.000Z',
      };

      final profile = IdentityProfile.fromJson(json);
      expect(profile.enrolled, isTrue);
      expect(profile.status, equals(IdentityProfileStatus.active));
      expect(profile.provider, equals('SANDBOX_PROVIDER'));
      expect(profile.noticeVersion, equals('v1.0'));
      expect(profile.consentedAt, isNotNull);
      expect(profile.enrolledAt, isNotNull);
      expect(profile.lastVerifiedAt, isNotNull);
      expect(profile.revokedAt, isNull);
    });

    test('TeamMemberIdentityStatus parses JSON correctly', () {
      final json = {
        'membership_id': '00000000-0000-0000-0000-000000000001',
        'user_id': '00000000-0000-0000-0000-000000000002',
        'employee_code': 'EMP-001',
        'first_name': 'Avi',
        'last_name': 'Cohen',
        'role': 'EMPLOYEE',
        'identity_status': 'ACTIVE',
        'enrolled_at': '2026-08-26T00:00:00.000Z',
      };

      final member = TeamMemberIdentityStatus.fromJson(json);
      expect(
          member.membershipId, equals('00000000-0000-0000-0000-000000000001'));
      expect(member.firstName, equals('Avi'));
      expect(member.lastName, equals('Cohen'));
      expect(member.identityStatus, equals(IdentityProfileStatus.active));
    });
  });

  group('IdentityVerificationAttempt and Proof Tests', () {
    test('FailureCategory maps to DB values correctly', () {
      expect(FailureCategory.faceMismatch.toDbValue(), equals('FACE_MISMATCH'));
      expect(FailureCategory.livenessFailed.toDbValue(),
          equals('LIVENESS_FAILED'));
      expect(FailureCategory.cameraUnavailable.toDbValue(),
          equals('CAMERA_UNAVAILABLE'));
      expect(FailureCategory.providerUnavailable.toDbValue(),
          equals('PROVIDER_UNAVAILABLE'));
      expect(FailureCategory.profileNotEnrolled.toDbValue(),
          equals('PROFILE_NOT_ENROLLED'));
      expect(FailureCategory.profileRevoked.toDbValue(),
          equals('PROFILE_REVOKED'));
      expect(FailureCategory.sessionExpired.toDbValue(),
          equals('SESSION_EXPIRED'));
      expect(
          FailureCategory.userCancelled.toDbValue(), equals('USER_CANCELLED'));
      expect(FailureCategory.inconclusive.toDbValue(), equals('INCONCLUSIVE'));
    });

    test('IdentityVerificationProof parses response correctly', () {
      final json = {
        'success': true,
        'identity_proof_token': 'IP_test_token_123',
        'expires_at': '2026-08-26T00:02:00.000Z',
        'action': 'CHECK_IN',
        'override_id': null,
      };

      final proof = IdentityVerificationProof.fromJson(json);
      expect(proof.success, isTrue);
      expect(proof.identityProofToken, equals('IP_test_token_123'));
      expect(proof.isOverride, isFalse);
    });
  });
}
