import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reports_repository.dart';
import '../../domain/models/station_attendance_summary.dart';
import '../../domain/models/employee_attendance_summary.dart';
import '../../domain/models/daily_attendance_report.dart';
import '../../domain/models/attendance_correction_detail.dart';
import 'my_hours_controller.dart';

enum ReportViewMode {
  breakdown,
  daily,
}

class StationReportsState {
  final ReportViewMode viewMode;
  final String stationId;
  final DatePreset preset;
  final DateTime fromDate;
  final DateTime toDate;
  final DateTime selectedDailyDate;
  final String searchQuery;
  final String sortBy;
  final String sortOrder;
  final StationAttendanceSummary? stationSummary;
  final List<EmployeeAttendanceSummary> employees;
  final int totalEmployeesCount;
  final DailyAttendanceReport? dailyReport;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int offset;
  final String? errorMessage;
  final StationEmployeeAttendanceDetailResponse? employeeDrilldown;
  final bool isDrilldownLoading;

  const StationReportsState({
    this.viewMode = ReportViewMode.breakdown,
    required this.stationId,
    required this.preset,
    required this.fromDate,
    required this.toDate,
    required this.selectedDailyDate,
    this.searchQuery = '',
    this.sortBy = 'name',
    this.sortOrder = 'asc',
    this.stationSummary,
    this.employees = const [],
    this.totalEmployeesCount = 0,
    this.dailyReport,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.offset = 0,
    this.errorMessage,
    this.employeeDrilldown,
    this.isDrilldownLoading = false,
  });

  StationReportsState copyWith({
    ReportViewMode? viewMode,
    String? stationId,
    DatePreset? preset,
    DateTime? fromDate,
    DateTime? toDate,
    DateTime? selectedDailyDate,
    String? searchQuery,
    String? sortBy,
    String? sortOrder,
    StationAttendanceSummary? stationSummary,
    List<EmployeeAttendanceSummary>? employees,
    int? totalEmployeesCount,
    DailyAttendanceReport? dailyReport,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? offset,
    String? errorMessage,
    bool clearError = false,
    StationEmployeeAttendanceDetailResponse? employeeDrilldown,
    bool clearDrilldown = false,
    bool? isDrilldownLoading,
  }) {
    return StationReportsState(
      viewMode: viewMode ?? this.viewMode,
      stationId: stationId ?? this.stationId,
      preset: preset ?? this.preset,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      selectedDailyDate: selectedDailyDate ?? this.selectedDailyDate,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      stationSummary: stationSummary ?? this.stationSummary,
      employees: employees ?? this.employees,
      totalEmployeesCount: totalEmployeesCount ?? this.totalEmployeesCount,
      dailyReport: dailyReport ?? this.dailyReport,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      employeeDrilldown:
          clearDrilldown ? null : (employeeDrilldown ?? this.employeeDrilldown),
      isDrilldownLoading: isDrilldownLoading ?? this.isDrilldownLoading,
    );
  }
}

final stationReportsControllerProvider = StateNotifierProvider.autoDispose
    .family<StationReportsNotifier, StationReportsState, String>(
        (ref, stationId) {
  final repo = ref.watch(reportsRepositoryProvider);
  return StationReportsNotifier(repo, stationId);
});

class StationReportsNotifier extends StateNotifier<StationReportsState> {
  final ReportsRepository _repo;
  Timer? _debounceTimer;

  StationReportsNotifier(this._repo, String stationId)
      : super(_initialState(stationId)) {
    loadData();
  }

  static StationReportsState _initialState(String stationId) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    return StationReportsState(
      stationId: stationId,
      preset: DatePreset.currentMonth,
      fromDate: firstDay,
      toDate: lastDay,
      selectedDailyDate: DateTime(now.year, now.month, now.day),
      isLoading: true,
    );
  }

  void setViewMode(ReportViewMode mode) {
    state = state.copyWith(viewMode: mode);
    loadData();
  }

  void setDailyDate(DateTime date) {
    state = state.copyWith(
      selectedDailyDate: DateTime(date.year, date.month, date.day),
    );
    if (state.viewMode == ReportViewMode.daily) {
      loadDailyReport();
    }
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
      employees: [],
    );
    loadData();
  }

  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query, offset: 0, employees: []);
      loadEmployees();
    });
  }

  void setSorting(String sortBy) {
    if (state.sortBy == sortBy) {
      final newOrder = state.sortOrder == 'asc' ? 'desc' : 'asc';
      state = state.copyWith(sortOrder: newOrder, offset: 0, employees: []);
    } else {
      state = state
          .copyWith(sortBy: sortBy, sortOrder: 'asc', offset: 0, employees: []);
    }
    loadEmployees();
  }

  Future<void> loadData() async {
    if (state.viewMode == ReportViewMode.daily) {
      await loadDailyReport();
    } else {
      await Future.wait([
        loadStationSummary(),
        loadEmployees(),
      ]);
    }
  }

  Future<void> loadStationSummary() async {
    try {
      final summary = await _repo.getStationAttendanceSummary(
        stationId: state.stationId,
        from: state.fromDate,
        to: state.toDate,
      );
      state = state.copyWith(stationSummary: summary);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repo.getStationEmployeeAttendanceSummary(
        stationId: state.stationId,
        from: state.fromDate,
        to: state.toDate,
        search: state.searchQuery,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        limit: 25,
        offset: 0,
      );

      final items = res['items'] as List<EmployeeAttendanceSummary>;
      final total = res['total_count'] as int;
      final hasMore = res['has_more'] as bool;

      state = state.copyWith(
        employees: items,
        totalEmployeesCount: total,
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

  Future<void> loadMoreEmployees() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextOffset = state.offset + 25;

    try {
      final res = await _repo.getStationEmployeeAttendanceSummary(
        stationId: state.stationId,
        from: state.fromDate,
        to: state.toDate,
        search: state.searchQuery,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        limit: 25,
        offset: nextOffset,
      );

      final newItems = res['items'] as List<EmployeeAttendanceSummary>;
      final hasMore = res['has_more'] as bool;

      state = state.copyWith(
        employees: [...state.employees, ...newItems],
        hasMore: hasMore,
        offset: nextOffset,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> loadDailyReport() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final report = await _repo.getStationDailyAttendanceReport(
        stationId: state.stationId,
        date: state.selectedDailyDate,
      );
      state = state.copyWith(
        dailyReport: report,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> openEmployeeDrilldown(String employeeUserId) async {
    state = state.copyWith(isDrilldownLoading: true, clearDrilldown: true);
    try {
      final detail = await _repo.getStationEmployeeAttendanceDetail(
        stationId: state.stationId,
        employeeUserId: employeeUserId,
        from: state.fromDate,
        to: state.toDate,
      );
      state = state.copyWith(
        employeeDrilldown: detail,
        isDrilldownLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDrilldownLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void closeEmployeeDrilldown() {
    state = state.copyWith(clearDrilldown: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
