import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../../data/system_health_repository.dart';
import '../../domain/models/station_system_health.dart';

class SystemHealthNotifier
    extends StateNotifier<AsyncValue<StationSystemHealth>> {
  final SystemHealthRepository _repository;
  final Ref _ref;
  final String? _activeStationId;

  SystemHealthNotifier(this._repository, this._ref, this._activeStationId)
      : super(const AsyncValue.loading()) {
    loadHealth();
  }

  Future<void> loadHealth() async {
    if (_activeStationId == null) {
      state = const AsyncValue.loading();
      return;
    }

    try {
      state = const AsyncValue.loading();
      final data = await _repository.getStationSystemHealth(_activeStationId);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, dynamic>?> triggerDataRetentionCleanup() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final res = await supabase.rpc('cleanup_expired_data');
      await loadHealth();
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return null;
    }
  }
}

final systemHealthControllerProvider = StateNotifierProvider<
    SystemHealthNotifier, AsyncValue<StationSystemHealth>>((ref) {
  final repository = ref.watch(systemHealthRepositoryProvider);
  final activeStationId = ref.watch(activeStationIdProvider);
  return SystemHealthNotifier(repository, ref, activeStationId);
});
