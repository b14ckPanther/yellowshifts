import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/availability_repository.dart';
import '../domain/availability_period.dart';

final currentAvailabilityPeriodProvider =
    FutureProvider.autoDispose<AvailabilityPeriod?>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return null;

  return ref
      .read(availabilityRepositoryProvider)
      .getCurrentAvailabilityPeriod(stationId);
});

final availabilityPeriodsListProvider =
    FutureProvider.autoDispose<List<AvailabilityPeriod>>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return [];

  return ref
      .read(availabilityRepositoryProvider)
      .listAvailabilityPeriods(stationId);
});
