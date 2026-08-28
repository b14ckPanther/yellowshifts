import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_filter_chip.dart';
import '../../../../core/design_system/components/app_segmented_control.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../controllers/station_reports_controller.dart';
import '../controllers/my_hours_controller.dart';
import '../widgets/kpi_summary_card.dart';
import '../widgets/employee_breakdown_table.dart';
import '../widgets/daily_shift_board.dart';
import '../widgets/employee_detail_sheet.dart';

class ManagerReportsScreen extends ConsumerStatefulWidget {
  const ManagerReportsScreen({super.key});

  @override
  ConsumerState<ManagerReportsScreen> createState() =>
      _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends ConsumerState<ManagerReportsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final station = ref.read(currentStationProvider);
    if (station == null) return;
    final state = ref.read(stationReportsControllerProvider(station.id));

    if (state.viewMode == ReportViewMode.breakdown &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(stationReportsControllerProvider(station.id).notifier)
          .loadMoreEmployees();
    }
  }

  String _formatHoursMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  Future<void> _selectCustomRange(
      BuildContext context, String stationId) async {
    final state = ref.read(stationReportsControllerProvider(stationId));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(
        start: state.fromDate,
        end: state.toDate,
      ),
    );

    if (picked != null) {
      ref
          .read(stationReportsControllerProvider(stationId).notifier)
          .setDatePreset(
            DatePreset.custom,
            customFrom: picked.start,
            customTo: picked.end,
          );
    }
  }

  Future<void> _selectDailyDate(BuildContext context, String stationId) async {
    final state = ref.read(stationReportsControllerProvider(stationId));
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDailyDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      ref
          .read(stationReportsControllerProvider(stationId).notifier)
          .setDailyDate(picked);
    }
  }

  void _showEmployeeDetailModal(
      BuildContext context, String stationId, String userId) {
    final notifier =
        ref.read(stationReportsControllerProvider(stationId).notifier);
    notifier.openEmployeeDrilldown(userId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state =
                ref.watch(stationReportsControllerProvider(stationId));
            if (state.isDrilldownLoading) {
              return Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (state.employeeDrilldown != null) {
              return EmployeeDetailSheet(
                detail: state.employeeDrilldown!,
                onClose: () {
                  Navigator.of(modalContext).pop();
                  notifier.closeEmployeeDrilldown();
                },
              );
            }
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Text(state.errorMessage ??
                    AppLocalizations.of(context)!.errorGeneric),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final station = ref.watch(currentStationProvider);
    final permissions = ref.watch(activeStationPermissionsProvider);

    if (station == null || !permissions.canViewReports) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.shieldAlert,
                  size: 48,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.reportsAccessRestrictedTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.reportsAccessRestrictedDesc,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(stationReportsControllerProvider(station.id));
    final notifier =
        ref.read(stationReportsControllerProvider(station.id).notifier);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => notifier.loadData(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Page Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space4,
                  ),
                  child: AppPageHeader(
                    title: '${station.name} - ${l10n.reportsTitle}',
                    subtitle: l10n.reportsSubtitle,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/reports/exports'),
                        icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                        label: Text(l10n.navExports),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // View Mode Segmented Control
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space4,
                  ),
                  child: AppSegmentedControl<ReportViewMode>(
                    selectedValue: state.viewMode,
                    segments: [
                      AppSegment(
                        value: ReportViewMode.breakdown,
                        label: l10n.tabBreakdown,
                        icon: LucideIcons.users,
                      ),
                      AppSegment(
                        value: ReportViewMode.daily,
                        label: l10n.tabDailyBoard,
                        icon: LucideIcons.calendarDays,
                      ),
                    ],
                    onValueChanged: (mode) => notifier.setViewMode(mode),
                  ),
                ),
              ),

              // Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space8,
                  ),
                  child: state.viewMode == ReportViewMode.breakdown
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Range Presets
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  AppFilterChip(
                                    label: l10n.presetToday,
                                    isSelected:
                                        state.preset == DatePreset.today,
                                    onSelected: (_) => notifier
                                        .setDatePreset(DatePreset.today),
                                  ),
                                  const SizedBox(width: AppSpacing.space8),
                                  AppFilterChip(
                                    label: l10n.presetCurrentWeek,
                                    isSelected:
                                        state.preset == DatePreset.currentWeek,
                                    onSelected: (_) => notifier
                                        .setDatePreset(DatePreset.currentWeek),
                                  ),
                                  const SizedBox(width: AppSpacing.space8),
                                  AppFilterChip(
                                    label: l10n.presetCurrentMonth,
                                    isSelected:
                                        state.preset == DatePreset.currentMonth,
                                    onSelected: (_) => notifier
                                        .setDatePreset(DatePreset.currentMonth),
                                  ),
                                  const SizedBox(width: AppSpacing.space8),
                                  AppFilterChip(
                                    label: l10n.presetLastMonth,
                                    isSelected:
                                        state.preset == DatePreset.lastMonth,
                                    onSelected: (_) => notifier
                                        .setDatePreset(DatePreset.lastMonth),
                                  ),
                                  const SizedBox(width: AppSpacing.space8),
                                  AppFilterChip(
                                    label: state.preset == DatePreset.custom
                                        ? '${state.fromDate.month}/${state.fromDate.day} - ${state.toDate.month}/${state.toDate.day}'
                                        : l10n.presetCustom,
                                    isSelected:
                                        state.preset == DatePreset.custom,
                                    onSelected: (_) =>
                                        _selectCustomRange(context, station.id),
                                    avatar: const Icon(LucideIcons.calendar,
                                        size: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space8),

                            // Search Field
                            AppTextField(
                              controller: _searchController,
                              hint: l10n.searchEmployeesPlaceholder,
                              prefixIcon: LucideIcons.search,
                              onChanged: (q) => notifier.setSearchQuery(q),
                            ),
                          ],
                        )
                      : // Daily Mode Date Picker
                      Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _selectDailyDate(context, station.id),
                              icon: const Icon(LucideIcons.calendar),
                              label: Text(
                                '${state.selectedDailyDate.year}-${state.selectedDailyDate.month.toString().padLeft(2, '0')}-${state.selectedDailyDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusMd),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            IconButton.outlined(
                              icon: const Icon(LucideIcons.chevronLeft),
                              onPressed: () {
                                notifier.setDailyDate(
                                  state.selectedDailyDate
                                      .subtract(const Duration(days: 1)),
                                );
                              },
                            ),
                            const SizedBox(width: AppSpacing.space4),
                            IconButton.outlined(
                              icon: const Icon(LucideIcons.chevronRight),
                              onPressed: () {
                                notifier.setDailyDate(
                                  state.selectedDailyDate
                                      .add(const Duration(days: 1)),
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),

              // KPI Executive Summary Grid
              if (state.viewMode == ReportViewMode.breakdown &&
                  state.stationSummary != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                      vertical: AppSpacing.space8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        final isTablet = constraints.maxWidth >= 600;
                        final summary = state.stationSummary!;

                        final cards = [
                          KpiSummaryCard(
                            title: l10n.kpiTotalWorked,
                            value:
                                _formatHoursMinutes(summary.totalWorkedMinutes),
                            subtitle: l10n.kpiActiveEmployees(
                                summary.employeesWithAttendanceCount),
                            icon: LucideIcons.clock,
                            accentColor: AppColors.colorSurfaceBrand,
                          ),
                          KpiSummaryCard(
                            title: l10n.kpiCompletedShifts,
                            value: '${summary.completedShifts}',
                            subtitle: summary.openSessions > 0
                                ? l10n.kpiActiveOpen(summary.openSessions)
                                : null,
                            icon: LucideIcons.calendarCheck,
                            accentColor: AppColors.colorStatusSuccess,
                          ),
                          KpiSummaryCard(
                            title: l10n.kpiOnTimeRate,
                            value:
                                '${summary.onTimePercentage.toStringAsFixed(1)}%',
                            subtitle: l10n.kpiLateShiftsCount(
                              summary.lateShifts,
                              summary.totalLateMinutes,
                            ),
                            icon: LucideIcons.timer,
                            accentColor: summary.onTimePercentage >= 90
                                ? AppColors.colorStatusSuccess
                                : AppColors.colorStatusWarning,
                          ),
                          KpiSummaryCard(
                            title: l10n.kpiRepeatedLateness,
                            value: '${summary.repeatedLatenessEmployeeCount}',
                            subtitle: l10n.kpiEmployeesLateThreshold,
                            icon: LucideIcons.triangleAlert,
                            accentColor: AppColors.colorStatusDanger,
                            badgeText: summary.repeatedLatenessEmployeeCount > 0
                                ? l10n.kpiAttentionBadge
                                : null,
                            badgeColor: AppColors.colorStatusDanger,
                          ),
                          KpiSummaryCard(
                            title: l10n.kpiCorrectedRecords,
                            value: '${summary.correctedRecords}',
                            subtitle: l10n.kpiManualAdjustmentsAudited,
                            icon: LucideIcons.fileCheck2,
                            accentColor: AppColors.colorStatusInfo,
                          ),
                        ];

                        if (isDesktop) {
                          return GridView.count(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.5,
                            children: cards,
                          );
                        } else if (isTablet) {
                          return GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.4,
                            children: cards,
                          );
                        } else {
                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.3,
                            children: cards,
                          );
                        }
                      },
                    ),
                  ),
                ),

              // Content Body: Breakdown Table vs Daily Board
              if (state.viewMode == ReportViewMode.breakdown) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                      vertical: AppSpacing.space8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.workforceRecordsTitle(state.totalEmployeesCount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (state.isLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (state.employees.isEmpty && !state.isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Center(
                        child: Text(
                          l10n.noAttendanceFound,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                        vertical: AppSpacing.space4,
                      ),
                      child: EmployeeBreakdownTable(
                        employees: state.employees,
                        sortBy: state.sortBy,
                        sortOrder: state.sortOrder,
                        onSort: (key) => notifier.setSorting(key),
                        onSelectEmployee: (emp) => _showEmployeeDetailModal(
                            context, station.id, emp.employeeUserId),
                      ),
                    ),
                  ),
                if (state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ] else ...[
                // Daily Board View
                if (state.dailyReport != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                        vertical: AppSpacing.space8,
                      ),
                      child: DailyShiftBoard(
                        report: state.dailyReport!,
                        onSelectRecord: (rec) => _showEmployeeDetailModal(
                            context, station.id, rec.userId),
                      ),
                    ),
                  ),
              ],

              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
