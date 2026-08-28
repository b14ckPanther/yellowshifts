import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/kiosk_repository.dart';
import '../../domain/models/kiosk_device.dart';
import '../../domain/models/qr_challenge.dart';
import '../../../../core/supabase/supabase_client_provider.dart';

final kioskRepositoryProvider = Provider<KioskRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return KioskRepository(client);
});

final stationKioskDevicesProvider =
    FutureProvider.family<List<KioskDevice>, String>((ref, stationId) async {
  final repo = ref.watch(kioskRepositoryProvider);
  return repo.getKioskDevices(stationId);
});

class KioskSessionState {
  final String stationId;
  final String deviceIdentifier;
  final String deviceSecret;
  final QrChallenge? currentChallenge;
  final bool isLoading;
  final String? errorMessage;

  const KioskSessionState({
    required this.stationId,
    required this.deviceIdentifier,
    required this.deviceSecret,
    this.currentChallenge,
    this.isLoading = false,
    this.errorMessage,
  });

  KioskSessionState copyWith({
    String? stationId,
    String? deviceIdentifier,
    String? deviceSecret,
    QrChallenge? currentChallenge,
    bool? isLoading,
    String? errorMessage,
  }) {
    return KioskSessionState(
      stationId: stationId ?? this.stationId,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceSecret: deviceSecret ?? this.deviceSecret,
      currentChallenge: currentChallenge ?? this.currentChallenge,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class KioskSessionNotifier extends StateNotifier<KioskSessionState?> {
  final KioskRepository _repo;

  KioskSessionNotifier(this._repo) : super(null);

  Future<void> startSession({
    required String stationId,
    required String deviceIdentifier,
    required String deviceSecret,
  }) async {
    state = KioskSessionState(
      stationId: stationId,
      deviceIdentifier: deviceIdentifier,
      deviceSecret: deviceSecret,
      isLoading: true,
    );
    await refreshQrChallenge();
    if (state?.errorMessage != null) {
      throw Exception(state!.errorMessage);
    }
  }

  void endSession() {
    state = null;
  }

  Future<void> refreshQrChallenge() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(isLoading: true, errorMessage: null);

    try {
      final challenge = await _repo.authenticateAndMintQr(
        stationId: current.stationId,
        deviceIdentifier: current.deviceIdentifier,
        deviceSecret: current.deviceSecret,
      );
      state = current.copyWith(
        currentChallenge: challenge,
        isLoading: false,
      );
    } catch (e) {
      state = current.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final kioskSessionProvider =
    StateNotifierProvider<KioskSessionNotifier, KioskSessionState?>((ref) {
  final repo = ref.watch(kioskRepositoryProvider);
  return KioskSessionNotifier(repo);
});
