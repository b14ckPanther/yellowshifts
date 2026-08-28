import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/identity_policy.dart';
import '../domain/models/identity_profile.dart';
import '../domain/models/identity_enrollment_session.dart';
import '../domain/models/identity_verification_attempt.dart';
import '../domain/models/identity_verification_proof.dart';

class IdentityRepository {
  final SupabaseClient _supabase;

  IdentityRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch current user's identity assurance profile
  Future<IdentityProfile> getMyIdentityProfile() async {
    final response = await _supabase.rpc('get_my_identity_profile');
    if (response == null) {
      return IdentityProfile.notEnrolledProfile;
    }
    return IdentityProfile.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Station Manager view: team biometric enrollment roster
  Future<List<TeamMemberIdentityStatus>> getStationTeamIdentityStatus(
      String stationId) async {
    final response = await _supabase.rpc(
      'get_station_team_identity_status',
      params: {'p_station_id': stationId},
    );

    if (response == null) return [];
    final list = (response as List)
        .map((item) => TeamMemberIdentityStatus.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
    return list;
  }

  /// Station Manager update policy: DISABLED, CHECK_IN_ONLY, CHECK_IN_AND_CHECK_OUT
  Future<void> updateStationIdentityPolicy({
    required String stationId,
    required IdentityVerificationMode mode,
  }) async {
    await _supabase.rpc(
      'update_station_identity_policy',
      params: {
        'p_station_id': stationId,
        'p_mode': mode.toDbValue(),
      },
    );
  }

  /// Start employee biometric enrollment flow
  Future<IdentityEnrollmentSession> startIdentityEnrollment({
    String provider = 'SANDBOX_PROVIDER',
    String noticeVersion = 'v1.0',
  }) async {
    final response = await _supabase.rpc(
      'start_identity_enrollment',
      params: {
        'p_provider': provider,
        'p_notice_version': noticeVersion,
      },
    );

    return IdentityEnrollmentSession.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  /// Complete biometric enrollment with provider subject id
  Future<void> completeIdentityEnrollment({
    required String sessionId,
    String? providerSubjectId,
    required bool success,
    FailureCategory? failureCategory,
  }) async {
    await _supabase.rpc(
      'complete_identity_enrollment',
      params: {
        'p_session_id': sessionId,
        'p_provider_subject_id': providerSubjectId,
        'p_success': success,
        'p_failure_category': failureCategory?.toDbValue(),
      },
    );
  }

  /// Employee self-revocation or Admin revocation
  Future<void> revokeIdentityProfile({
    String? employeeUserId,
    String? reason,
  }) async {
    await _supabase.rpc(
      'revoke_identity_profile',
      params: {
        'p_employee_user_id': employeeUserId,
        'p_reason': reason,
      },
    );
  }

  /// Start identity verification attempt bound to station presence proof
  Future<IdentityVerificationSessionInit> startIdentityVerification({
    required String presenceProofToken,
    String provider = 'SANDBOX_PROVIDER',
  }) async {
    final response = await _supabase.rpc(
      'start_identity_verification',
      params: {
        'p_presence_proof_token': presenceProofToken,
        'p_provider': provider,
      },
    );

    return IdentityVerificationSessionInit.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  /// Complete verification attempt and mint short-lived identity proof token
  Future<IdentityVerificationProof> completeIdentityVerification({
    required String attemptId,
    required bool isVerified,
    FailureCategory? failureCategory,
  }) async {
    final response = await _supabase.rpc(
      'complete_identity_verification',
      params: {
        'p_attempt_id': attemptId,
        'p_is_verified': isVerified,
        'p_failure_category': failureCategory?.toDbValue(),
      },
    );

    return IdentityVerificationProof.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  /// Manager in-person override for camera/device failures
  Future<IdentityVerificationProof> createIdentityAdminOverride({
    required String presenceProofToken,
    required String reason,
  }) async {
    final response = await _supabase.rpc(
      'create_identity_admin_override',
      params: {
        'p_presence_proof_token': presenceProofToken,
        'p_reason': reason,
      },
    );

    return IdentityVerificationProof.fromJson(
        Map<String, dynamic>.from(response as Map));
  }
}
