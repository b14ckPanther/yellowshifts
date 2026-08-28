import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_state_provider.dart';
import '../../data/reports_repository.dart';
import '../../domain/models/attendance_summary.dart';
import '../../domain/models/attendance_history_item.dart';

enum DatePreset {
  today,
  currentWeek,
  currentMonth,
  lastMonth,
  custom,
}

class MyHoursState {
  final DatePreset preset;
  final DateTime fromDate;
  final DateTime toDate;
  final String? selectedStationId;
  final String? statusFilter;
  final AttendanceSummary? summary;
  final List<AttendanceHistoryItem> historyItems;
  final int totalHistoryCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int offset;
  final String? errorMessage;

  const MyHoursState({
    required this.preset,
    required this.fromDate,
    required this.toDate,
    this.selectedStationId,
    this.statusFilter,
    this.summary,
    this.historyItems = const [],
    this.totalHistoryCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.offset = 0,
    this.errorMessage,
  });

  MyHoursState copyWith({
    DatePreset? preset,
    DateTime? fromDate,
    DateTime? toDate,
    String? selectedStationId,
    bool clearStation = false,
    String? statusFilter,
    bool clearStatusFilter = false,
    AttendanceSummary? summary,
    List<AttendanceHistoryItem>? historyItems,
    int? totalHistoryCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? offset,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyHoursState(
      preset: preset ?? this.preset,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      selectedStationId:
          clearStation ? null : (selectedStationId ?? this.selectedStationId),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      summary: summary ?? this.summary,
      historyItems: historyItems ?? this.historyItems,
      totalHistoryCount: totalHistoryCount ?? this.totalHistoryCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final myHoursControllerProvider =
    StateNotifierProvider.autoDispose<MyHoursNotifier, MyHoursState>((ref) {
  final repo = ref.watch(reportsRepositoryProvider);
  return MyHoursNotifier(ref, repo);
});

class MyHoursNotifier extends StateNotifier<MyHoursState> {
  final Ref _ref;
  final ReportsRepository _repo;

  MyHoursNotifier(this._ref, this._repo) : super(_initialState()) {
    loadData();
  }

  static MyHoursState _initialState() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    return MyHoursState(
      preset: DatePreset.currentMonth,
      fromDate: firstDayOfMonth,
      toDate: lastDayOfMonth,
      isLoading: true,
    );
  }

  void setDatePreset(DatePreset preset,
      {DateTime? customFrom, DateTime? customTo}) {
    final now = DateTime.now();
    DateTime from;
    DateTime to;

    switch (preset) {
      case DatePreset.today:
        from = DateTime(now.year, now.month, now.day);
        to = from;
        break;
      case DatePreset.currentWeek:
        // Week starts Sunday (weekday 7 in Dart or adjusted)
        final diff = now.weekday % 7;
        from = DateTime(now.year, now.month, now.day - diff);
        to = from.add(const Duration(days: 6));
        break;
      case DatePreset.currentMonth:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case DatePreset.lastMonth:
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0);
        break;
      case DatePreset.custom:
        from = customFrom ?? state.fromDate;
        to = customTo ?? state.toDate;
        break;
    }

    state = state.copyWith(
      preset: preset,
      fromDate: from,
      toDate: to,
      offset: 0,
      historyItems: [],
    );
    loadData();
  }

  void setStationFilter(String? stationId) {
    if (stationId == null || stationId.isEmpty) {
      state = state.copyWith(clearStation: true, offset: 0, historyItems: []);
    } else {
      state = state
          .copyWith(selectedStationId: stationId, offset: 0, historyItems: []);
    }
    loadData();
  }

  void setStatusFilter(String? filter) {
    if (filter == null || filter == 'ALL' || filter.isEmpty) {
      state =
          state.copyWith(clearStatusFilter: true, offset: 0, historyItems: []);
    } else {
      state = state.copyWith(statusFilter: filter, offset: 0, historyItems: []);
    }
    loadData();
  }

  Future<void> loadData() async {
    final profile = _ref.read(currentProfileProvider).value;
    if (profile == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final summary = await _repo.getMyAttendanceSummary(
        from: state.fromDate,
        to: state.toDate,
        stationId: state.selectedStationId,
      );

      final historyRes = await _repo.getMyAttendanceHistory(
        from: state.fromDate,
        to: state.toDate,
        stationId: state.selectedStationId,
        statusFilter: state.statusFilter,
        limit: 25,
        offset: 0,
      );

      final items = historyRes['items'] as List<AttendanceHistoryItem>;
      final total = historyRes['total_count'] as int;
      final hasMore = historyRes['has_more'] as bool;

      state = state.copyWith(
        summary: summary,
        historyItems: items,
        totalHistoryCount: total,
        hasMore: hasMore,
        offset: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMoreHistory() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextOffset = state.offset + 25;

    try {
      final historyRes = await _repo.getMyAttendanceHistory(
        from: state.fromDate,
        to: state.toDate,
        stationId: state.selectedStationId,
        statusFilter: state.statusFilter,
        limit: 25,
        offset: nextOffset,
      );

      final newItems = historyRes['items'] as List<AttendanceHistoryItem>;
      final hasMore = historyRes['has_more'] as bool;

      state = state.copyWith(
        historyItems: [...state.historyItems, ...newItems],
        hasMore: hasMore,
        offset: nextOffset,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
