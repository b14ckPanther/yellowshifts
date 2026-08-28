import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/permissions_repository.dart';
import '../domain/shift_manager_permissions.dart';

final shiftManagerPermissionsProvider = AsyncNotifierProvider.autoDispose<
    ShiftManagerPermissionsNotifier, ShiftManagerPermissions>(() {
  return ShiftManagerPermissionsNotifier();
});

class ShiftManagerPermissionsNotifier
    extends AutoDisposeAsyncNotifier<ShiftManagerPermissions> {
  @override
  Future<ShiftManagerPermissions> build() async {
    final stationId = ref.watch(activeStationIdProvider);
    if (stationId == null) return const ShiftManagerPermissions();

    final repo = ref.read(permissionsRepositoryProvider);
    return repo.getShiftManagerPermissions(stationId);
  }

  Future<void> updatePermissions(ShiftManagerPermissions newPermissions) async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(permissionsRepositoryProvider)
          .updateShiftManagerPermissions(stationId, newPermissions);
      return newPermissions;
    });
  }
}
