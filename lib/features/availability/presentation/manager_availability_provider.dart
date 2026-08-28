import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/availability_repository.dart';
import '../domain/availability_matrix.dart';
import 'active_period_provider.dart';

class ManagerAvailabilityFilterState {
  final String? periodId;
  final String searchQuery;
  final String? statusFilter;
  final String? roleFilter;

  const ManagerAvailabilityFilterState({
    this.periodId,
    this.searchQuery = '',
    this.statusFilter,
    this.roleFilter,
  });

  ManagerAvailabilityFilterState copyWith({
    String? periodId,
    String? searchQuery,
    String? statusFilter,
    String? roleFilter,
  }) {
    return ManagerAvailabilityFilterState(
      periodId: periodId ?? this.periodId,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter,
      roleFilter: roleFilter,
    );
  }
}

final managerAvailabilityFilterProvider =
    StateProvider.autoDispose<ManagerAvailabilityFilterState>((ref) {
  return const ManagerAvailabilityFilterState();
});

final managerAvailabilityMatrixProvider = FutureProvider.autoDispose
    .family<AvailabilityMatrix?, String>((ref, periodId) async {
  final filter = ref.watch(managerAvailabilityFilterProvider);
  final repo = ref.read(availabilityRepositoryProvider);

  return repo.getAvailabilityMatrix(
    periodId: periodId,
    search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
    statusFilter: filter.statusFilter,
    roleFilter: filter.roleFilter,
  );
});

final managerAvailabilityControllerProvider =
    Provider.autoDispose<ManagerAvailabilityController>((ref) {
  return ManagerAvailabilityController(ref);
});

class ManagerAvailabilityController {
  final Ref _ref;

  ManagerAvailabilityController(this._ref);

  Future<void> openPeriod(String periodId) async {
    await _ref
        .read(availabilityRepositoryProvider)
        .openAvailabilityPeriod(periodId);
    _ref.invalidate(availabilityPeriodsListProvider);
    _ref.invalidate(currentAvailabilityPeriodProvider);
    _ref.invalidate(managerAvailabilityMatrixProvider(periodId));
  }

  Future<void> closePeriod(String periodId) async {
    await _ref
        .read(availabilityRepositoryProvider)
        .closeAvailabilityPeriod(periodId);
    _ref.invalidate(availabilityPeriodsListProvider);
    _ref.invalidate(currentAvailabilityPeriodProvider);
    _ref.invalidate(managerAvailabilityMatrixProvider(periodId));
  }

  Future<void> reopenPeriod(String periodId, DateTime newDeadline) async {
    await _ref
        .read(availabilityRepositoryProvider)
        .reopenAvailabilityPeriod(periodId, newDeadline);
    _ref.invalidate(availabilityPeriodsListProvider);
    _ref.invalidate(currentAvailabilityPeriodProvider);
    _ref.invalidate(managerAvailabilityMatrixProvider(periodId));
  }
}
