import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state_provider.dart';
import '../../../core/permissions/platform_admin_provider.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../core/permissions/station_permissions.dart';
import '../data/membership_repository.dart';
import '../domain/station_membership.dart';
import '../domain/station.dart';

final userMembershipsStreamProvider =
    StreamProvider<List<StationMembership>>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(membershipRepositoryProvider);
  return repo.streamMembershipsForUser(user.id);
});

class ActiveStationIdNotifier extends StateNotifier<String?> {
  final Ref? _ref;
  bool _retainWithoutMembership = false;

  ActiveStationIdNotifier([this._ref, String? initial]) : super(initial) {
    if (_ref != null) {
      _init();
    }
  }

  void _init() {
    _ref?.listen<AsyncValue<List<StationMembership>>>(
      userMembershipsStreamProvider,
      (previous, next) {
        next.whenData((memberships) {
          if (memberships.isEmpty) {
            if (!_retainWithoutMembership) {
              state = null;
            }
          } else if (state == null ||
              (!memberships.any((m) => m.stationId == state) &&
                  !_retainWithoutMembership)) {
            state = memberships.first.stationId;
          }
        });
      },
      fireImmediately: true,
    );
  }

  void selectStation(String stationId) {
    _retainWithoutMembership = false;
    state = stationId;
  }

  /// Platform Admin operating a station without a membership row.
  void operateStation(String stationId) {
    _retainWithoutMembership = true;
    state = stationId;
  }

  void exitOperatingStation() {
    _retainWithoutMembership = false;
    final memberships = _ref?.read(userMembershipsStreamProvider).value ??
        const <StationMembership>[];
    state = memberships.isEmpty ? null : memberships.first.stationId;
  }
}

final activeStationIdProvider =
    StateNotifierProvider<ActiveStationIdNotifier, String?>((ref) {
  return ActiveStationIdNotifier(ref);
});

final activeMembershipProvider = Provider<StationMembership?>((ref) {
  final activeId = ref.watch(activeStationIdProvider);
  if (activeId == null) return null;

  final memberships = ref.watch(userMembershipsStreamProvider).value ?? [];
  try {
    return memberships.firstWhere((m) => m.stationId == activeId);
  } catch (_) {
    return memberships.isNotEmpty ? memberships.first : null;
  }
});

final activeStationPermissionsProvider = Provider<StationPermissions>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  final access = ref.watch(stationAccessContextProvider);
  return StationPermissions.fromMembership(membership, accessContext: access);
});

final currentStationProvider = Provider<Station?>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  if (membership?.station != null) return membership!.station;

  final operatingId = ref.watch(platformOperatingStationIdProvider);
  if (operatingId == null) return null;
  return Station(
    id: operatingId,
    name: '',
    code: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
});

final stationsProvider = userMembershipsStreamProvider;
