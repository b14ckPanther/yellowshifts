import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../../data/audit_repository.dart';
import '../../domain/models/audit_log_entry.dart';

class AuditCenterState {
  final List<AuditLogEntry> items;
  final int totalCount;
  final bool isLoading;
  final String selectedCategory;
  final String searchQuery;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;
  final int pageSize;
  final String? errorMessage;

  const AuditCenterState({
    this.items = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.selectedCategory = 'ALL',
    this.searchQuery = '',
    this.dateFrom,
    this.dateTo,
    this.page = 0,
    this.pageSize = 50,
    this.errorMessage,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNextPage => (page + 1) * pageSize < totalCount;
  bool get hasPreviousPage => page > 0;

  AuditCenterState copyWith({
    List<AuditLogEntry>? items,
    int? totalCount,
    bool? isLoading,
    String? selectedCategory,
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    int? pageSize,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuditCenterState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuditCenterNotifier extends StateNotifier<AuditCenterState> {
  final AuditRepository _repository;
  final String? _activeStationId;

  AuditCenterNotifier(this._repository, this._activeStationId)
      : super(const AuditCenterState(isLoading: true)) {
    loadLogs();
  }

  Future<void> loadLogs({int? targetPage}) async {
    if (_activeStationId == null) {
      state = state.copyWith(isLoading: false, items: [], totalCount: 0);
      return;
    }

    final newPage = targetPage ?? state.page;
    state = state.copyWith(isLoading: true, page: newPage, clearError: true);

    try {
      final result = await _repository.queryAuditLogs(
        stationId: _activeStationId,
        from: state.dateFrom,
        to: state.dateTo,
        actionCategory:
            state.selectedCategory == 'ALL' ? null : state.selectedCategory,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        limit: state.pageSize,
        offset: newPage * state.pageSize,
      );

      state = state.copyWith(
        isLoading: false,
        items: result.items,
        totalCount: result.totalCount,
      );
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    }
  }

  void setCategory(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category, page: 0);
    loadLogs(targetPage: 0);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, page: 0);
    loadLogs(targetPage: 0);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(dateFrom: from, dateTo: to, page: 0);
    loadLogs(targetPage: 0);
  }

  void nextPage() {
    if (state.hasNextPage) {
      loadLogs(targetPage: state.page + 1);
    }
  }

  void previousPage() {
    if (state.hasPreviousPage) {
      loadLogs(targetPage: state.page - 1);
    }
  }
}

final auditCenterControllerProvider =
    StateNotifierProvider<AuditCenterNotifier, AuditCenterState>((ref) {
  final repository = ref.watch(auditRepositoryProvider);
  final activeStationId = ref.watch(activeStationIdProvider);
  return AuditCenterNotifier(repository, activeStationId);
});
