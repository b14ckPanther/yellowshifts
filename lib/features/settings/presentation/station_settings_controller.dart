import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/data/station_repository.dart';
import '../../stations/domain/station.dart';
import '../../dashboard/presentation/station_pulse_provider.dart';

class StationSettingsState {
  final bool isLoading;
  final String? error;
  final bool isSaved;

  const StationSettingsState({
    this.isLoading = false,
    this.error,
    this.isSaved = false,
  });

  StationSettingsState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isSaved,
  }) {
    return StationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class StationSettingsController extends StateNotifier<StationSettingsState> {
  final StationRepository _repository;
  final Ref _ref;

  StationSettingsController(this._repository, this._ref)
      : super(const StationSettingsState());

  Future<void> saveSettings({
    required String stationId,
    required String name,
    required String code,
    required String timezone,
    required String locale,
    required int weekStart,
    required bool isActive,
    int lateGraceMinutes = 5,
    int checkInEarlyMinutes = 15,
    bool forceDeactivate = false,
    String? deactivationReason,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSaved: false);

    try {
      final updatedStation = Station(
        id: stationId,
        name: name.trim(),
        code: code.trim().toUpperCase(),
        timezone: timezone,
        locale: locale,
        weekStart: weekStart,
        isActive: isActive,
        lateGraceMinutes: lateGraceMinutes,
        checkInEarlyMinutes: checkInEarlyMinutes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.updateStation(
        updatedStation,
        forceDeactivate: forceDeactivate,
        deactivationReason: deactivationReason,
      );

      state = state.copyWith(isLoading: false, isSaved: true);

      _ref.invalidate(stationPulseProvider);
    } catch (e) {
      final errorMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('AppFailure: ', '');
      state = state.copyWith(isLoading: false, error: errorMsg);
      rethrow;
    }
  }
}

final stationSettingsControllerProvider =
    StateNotifierProvider<StationSettingsController, StationSettingsState>(
        (ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationSettingsController(repository, ref);
});
