import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/data/station_repository.dart';
import '../../stations/presentation/active_station_provider.dart';

final stationPulseProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return {};

  final repository = ref.watch(stationRepositoryProvider);
  return await repository.getStationPulse(stationId);
});
