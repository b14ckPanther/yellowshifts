import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/platform_admin_repository.dart';
import '../domain/platform_audit_entry.dart';
import '../domain/platform_overview.dart';
import '../domain/platform_station_manager.dart';
import '../domain/platform_station_summary.dart';

final platformOverviewProvider = FutureProvider<PlatformOverview>((ref) {
  return ref.watch(platformAdminRepositoryProvider).getOverview();
});

final platformStationsProvider =
    FutureProvider<List<PlatformStationSummary>>((ref) {
  return ref.watch(platformAdminRepositoryProvider).listStations();
});

final platformStationManagersProvider =
    FutureProvider.family<List<PlatformStationManager>, String>(
        (ref, stationId) {
  return ref
      .watch(platformAdminRepositoryProvider)
      .getStationManagers(stationId);
});

class PlatformAuditQuery {
  final String? stationId;
  final String? action;
  final int offset;

  const PlatformAuditQuery({this.stationId, this.action, this.offset = 0});

  PlatformAuditQuery copyWith({
    String? stationId,
    bool clearStation = false,
    String? action,
    bool clearAction = false,
    int? offset,
  }) {
    return PlatformAuditQuery(
      stationId: clearStation ? null : (stationId ?? this.stationId),
      action: clearAction ? null : (action ?? this.action),
      offset: offset ?? this.offset,
    );
  }
}

final platformAuditQueryProvider =
    StateProvider<PlatformAuditQuery>((ref) => const PlatformAuditQuery());

final platformAuditProvider = FutureProvider<PlatformAuditPage>((ref) {
  final query = ref.watch(platformAuditQueryProvider);
  return ref.watch(platformAdminRepositoryProvider).queryAuditLogs(
        stationId: query.stationId,
        action: query.action,
        offset: query.offset,
      );
});
