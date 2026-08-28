import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_filter_chip.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../controllers/my_hours_controller.dart';
import '../controllers/export_center_controller.dart';
import '../../domain/models/report_export_model.dart';
import '../widgets/active_session_card.dart';

import '../widgets/kpi_summary_card.dart';
import '../widgets/history_timeline_tile.dart';

class EmployeeMyHoursScreen extends ConsumerStatefulWidget {
  const EmployeeMyHoursScreen({super.key});

  @override
  ConsumerState<EmployeeMyHoursScreen> createState() =>
      _EmployeeMyHoursScreenState();
}

class _EmployeeMyHoursScreenState extends ConsumerState<EmployeeMyHoursScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(myHoursControllerProvider.notifier).loadMoreHistory();
    }
  }

  String _formatHoursMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  Future<void> _selectCustomRange(BuildContext context) async {
    final state = ref.read(myHoursControllerProvider);
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
      ref.read(myHoursControllerProvider.notifier).setDatePreset(
            DatePreset.custom,
            customFrom: picked.start,
            customTo: picked.end,
          );
    }
  }

  Future<void> _exportPersonalHours(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(myHoursControllerProvider);
    final notifier = ref.read(exportCenterControllerProvider.notifier);

    AppFeedback.show(context, message: l10n.exportGenerating);

    final result = await notifier.requestAndGenerateExport(
      exportType: ReportExportType.myAttendanceHistory,
      format: ExportFormat.csv,
      from: state.fromDate,
      to: state.toDate,
    );

    if (context.mounted) {
      if (result != null && result.success) {
        AppFeedback.show(
          context,
          message: l10n.exportSuccess(result.rowCount),
          type: AppFeedbackType.success,
        );
      } else {
        AppFeedback.show(context,
            message: l10n.errorGeneric, type: AppFeedbackType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(myHoursControllerProvider);
    final memberships = ref.watch(userMembershipsStreamProvider).value ?? [];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(myHoursControllerProvider.notifier).loadData(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space8,
                  ),
                  child: AppPageHeader(
                    title: l10n.myHoursTitle,
                    subtitle: l10n.myHoursSubtitle,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => _exportPersonalHours(context),
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: Text(l10n.exportMyHours),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Controls (Presets & Station Selector)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Preset Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            AppFilterChip(
                              label: l10n.presetToday,
                              isSelected: state.preset == DatePreset.today,
                              onSelected: (_) => ref
                                  .read(myHoursControllerProvider.notifier)
                                  .setDatePreset(DatePreset.today),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            AppFilterChip(
                              label: l10n.presetCurrentWeek,
                              isSelected:
                                  state.preset == DatePreset.currentWeek,
                              onSelected: (_) => ref
                                  .read(myHoursControllerProvider.notifier)
                                  .setDatePreset(DatePreset.currentWeek),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            AppFilterChip(
                              label: l10n.presetCurrentMonth,
                              isSelected:
                                  state.preset == DatePreset.currentMonth,
                              onSelected: (_) => ref
                                  .read(myHoursControllerProvider.notifier)
                                  .setDatePreset(DatePreset.currentMonth),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            AppFilterChip(
                              label: l10n.presetLastMonth,
                              isSelected: state.preset == DatePreset.lastMonth,
                              onSelected: (_) => ref
                                  .read(myHoursControllerProvider.notifier)
                                  .setDatePreset(DatePreset.lastMonth),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                            AppFilterChip(
                              label: state.preset == DatePreset.custom
                                  ? '${state.fromDate.month}/${state.fromDate.day} - ${state.toDate.month}/${state.toDate.day}'
                                  : l10n.presetCustom,
                              isSelected: state.preset == DatePreset.custom,
                              onSelected: (_) => _selectCustomRange(context),
                              avatar:
                                  const Icon(LucideIcons.calendar, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space8),

                      // Secondary Filter: Station & Status
                      Row(
                        children: [
                          if (memberships.length > 1) ...[
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusMd),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: state.selectedStationId,
                                    isExpanded: true,
                                    hint: Text(l10n.allStationsFilter),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(l10n.allStationsFilter),
                                      ),
                                      ...memberships.map(
                                        (m) => DropdownMenuItem<String?>(
                                          value: m.stationId,
                                          child: Text(
                                              m.station?.name ?? m.stationId),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) => ref
                                        .read(
                                            myHoursControllerProvider.notifier)
                                        .setStationFilter(val),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space8),
                          ],

                          // Status Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.radiusMd),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: state.statusFilter,
                                  isExpanded: true,
                                  hint: Text(l10n.filterAll),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(l10n.filterAll),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'COMPLETED',
                                      child: Text(l10n.filterCompleted),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'LATE',
                                      child: Text(l10n.filterLate),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'CORRECTED',
                                      child: Text(l10n.filterCorrected),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'OPEN',
                                      child: Text(l10n.filterOpen),
                                    ),
                                  ],
                                  onChanged: (val) => ref
                                      .read(myHoursControllerProvider.notifier)
                                      .setStatusFilter(val),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Active Open Session (if present)
              if (state.summary?.activeOpenSession != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                      vertical: AppSpacing.space4,
                    ),
                    child: ActiveSessionCard(
                      session: state.summary!.activeOpenSession!,
                    ),
                  ),
                ),

              // KPI Cards Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      final summary = state.summary;
                      final totalWorked = summary?.totalWorkedMinutes ?? 0;
                      final completed = summary?.completedShifts ?? 0;
                      final lateShifts = summary?.lateShifts ?? 0;
                      final lateMins = summary?.totalLateMinutes ?? 0;
                      final corrected = summary?.correctedRecords ?? 0;

                      final cards = [
                        KpiSummaryCard(
                          title: l10n.kpiTotalWorked,
                          value: _formatHoursMinutes(totalWorked),
                          subtitle:
                              summary != null && summary.stationsWorkedCount > 1
                                  ? l10n.stationsWorkedCount(
                                      summary.stationsWorkedCount)
                                  : null,
                          icon: LucideIcons.clock,
                          accentColor: AppColors.colorSurfaceBrand,
                        ),
                        KpiSummaryCard(
                          title: l10n.kpiCompletedShifts,
                          value: '$completed',
                          icon: LucideIcons.calendarCheck,
                          accentColor: AppColors.colorStatusSuccess,
                        ),
                        KpiSummaryCard(
                          title: l10n.kpiLateShifts,
                          value: '$lateShifts',
                          subtitle: lateMins > 0
                              ? l10n.lateTimeDuration(lateMins)
                              : null,
                          icon: LucideIcons.alarmClockOff,
                          accentColor: AppColors.colorStatusDanger,
                          badgeText:
                              lateShifts >= 3 ? l10n.repeatedBadge : null,
                          badgeColor: AppColors.colorStatusDanger,
                        ),
                        KpiSummaryCard(
                          title: l10n.kpiCorrectedRecords,
                          value: '$corrected',
                          icon: LucideIcons.fileCheck2,
                          accentColor: AppColors.colorStatusInfo,
                        ),
                      ];

                      if (isWide) {
                        return GridView.count(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.6,
                          children: cards,
                        );
                      } else {
                        return GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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

              // Timeline Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.shiftHistoryTitle(state.totalHistoryCount),
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

              // History List Items
              if (state.historyItems.isEmpty && !state.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                      vertical: 36,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.calendarX,
                            size: 42,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noAttendanceFound,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space4,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = state.historyItems[index];
                        return HistoryTimelineTile(item: item);
                      },
                      childCount: state.historyItems.length,
                    ),
                  ),
                ),

              // Bottom Loading Indicator for Pagination
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

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
