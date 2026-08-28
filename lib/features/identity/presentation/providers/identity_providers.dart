import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/identity_repository.dart';
import '../../domain/identity_provider.dart';
import '../../domain/models/identity_policy.dart';
import '../../domain/models/identity_profile.dart';
import '../../domain/models/identity_verification_attempt.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepository();
});

final identityVerificationProvider =
    Provider<IdentityVerificationProvider>((ref) {
  return const SandboxIdentityProvider();
});

/// Current user's identity profile
final myIdentityProfileProvider =
    FutureProvider.autoDispose<IdentityProfile>((ref) async {
  final repo = ref.watch(identityRepositoryProvider);
  return repo.getMyIdentityProfile();
});

/// Station team identity roster (Manager view)
final stationTeamIdentityProvider = FutureProvider.autoDispose
    .family<List<TeamMemberIdentityStatus>, String>((ref, stationId) async {
  final repo = ref.watch(identityRepositoryProvider);
  return repo.getStationTeamIdentityStatus(stationId);
});

/// Controller for Biometric Enrollment & Revocation lifecycle
class IdentityEnrollmentState {
  final bool isLoading;
  final String? error;
  final bool success;

  const IdentityEnrollmentState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });
}

class IdentityEnrollmentController
    extends StateNotifier<IdentityEnrollmentState> {
  final IdentityRepository _repo;
  final IdentityVerificationProvider _provider;
  final Ref _ref;

  IdentityEnrollmentController(this._repo, this._provider, this._ref)
      : super(const IdentityEnrollmentState());

  Future<bool> enroll({String noticeVersion = 'v1.0'}) async {
    state = const IdentityEnrollmentState(isLoading: true);
    try {
      // 1. Start server session
      final session = await _repo.startIdentityEnrollment(
        provider: _provider.providerIdentifier,
        noticeVersion: noticeVersion,
      );

      // 2. Perform provider enrollment on client (zero raw data sent to backend)
      final providerResult = await _provider.startAndCompleteEnrollment(
        providerSessionId: session.providerSessionId,
      );

      if (!providerResult.success) {
        await _repo.completeIdentityEnrollment(
          sessionId: session.sessionId,
          success: false,
          failureCategory: providerResult.failureCategory ??
              FailureCategory.cameraUnavailable,
        );
        state = IdentityEnrollmentState(
          error: providerResult.errorMessage ?? 'Biometric enrollment failed',
        );
        return false;
      }

      // 3. Complete enrollment on server with opaque subject id
      await _repo.completeIdentityEnrollment(
        sessionId: session.sessionId,
        providerSubjectId: providerResult.providerSubjectId,
        success: true,
      );

      _ref.invalidate(myIdentityProfileProvider);
      state = const IdentityEnrollmentState(success: true);
      return true;
    } catch (e) {
      state = IdentityEnrollmentState(error: e.toString());
      return false;
    }
  }

  Future<bool> revoke({String? reason}) async {
    state = const IdentityEnrollmentState(isLoading: true);
    try {
      await _repo.revokeIdentityProfile(reason: reason);
      _ref.invalidate(myIdentityProfileProvider);
      state = const IdentityEnrollmentState(success: true);
      return true;
    } catch (e) {
      state = IdentityEnrollmentState(error: e.toString());
      return false;
    }
  }
}

final identityEnrollmentControllerProvider = StateNotifierProvider.autoDispose<
    IdentityEnrollmentController, IdentityEnrollmentState>((ref) {
  return IdentityEnrollmentController(
    ref.watch(identityRepositoryProvider),
    ref.watch(identityVerificationProvider),
    ref,
  );
});

/// Controller for Policy Management (Admin/Manager)
class StationPolicyController extends StateNotifier<AsyncValue<void>> {
  final IdentityRepository _repo;
  final Ref _ref;

  StationPolicyController(this._repo, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> updatePolicy({
    required String stationId,
    required IdentityVerificationMode mode,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateStationIdentityPolicy(
        stationId: stationId,
        mode: mode,
      );
      _ref.invalidate(stationTeamIdentityProvider(stationId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final stationPolicyControllerProvider = StateNotifierProvider.autoDispose<
    StationPolicyController, AsyncValue<void>>((ref) {
  return StationPolicyController(
    ref.watch(identityRepositoryProvider),
    ref,
  );
});
