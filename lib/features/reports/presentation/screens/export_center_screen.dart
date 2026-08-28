import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/permissions/station_access_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/export_center_controller.dart';
import '../../domain/models/report_export_model.dart';

class ExportCenterScreen extends ConsumerStatefulWidget {
  const ExportCenterScreen({super.key});

  @override
  ConsumerState<ExportCenterScreen> createState() => _ExportCenterScreenState();
}

class _ExportCenterScreenState extends ConsumerState<ExportCenterScreen> {
  ReportExportType _selectedType = ReportExportType.stationAttendanceSummary;
  ExportFormat _selectedFormat = ExportFormat.csv;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = now;
  }

  void _selectDatePreset(int days) {
    setState(() {
      final now = DateTime.now();
      _dateTo = now;
      if (days == 0) {
        _dateFrom = DateTime(now.year, now.month, 1);
      } else if (days == -1) {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        _dateFrom = prevMonth;
        _dateTo = DateTime(now.year, now.month, 0);
      } else {
        _dateFrom = now.subtract(Duration(days: days));
      }
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      if (picked.end.difference(picked.start).inDays > 366) {
        if (mounted) {
          AppFeedback.show(this.context,
              message: l10n.errorInvalidInput, type: AppFeedbackType.error);
        }
        return;
      }
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  Future<void> _handleGenerate() async {
    final notifier = ref.read(exportCenterControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final result = await notifier.requestAndGenerateExport(
      exportType: _selectedType,
      format: _selectedFormat,
      from: _dateFrom,
      to: _dateTo,
    );

    if (mounted) {
      if (result != null && result.success) {
        AppFeedback.show(
          context,
          message: l10n.exportSuccess(result.rowCount),
          type: AppFeedbackType.success,
        );
      } else {
        final state = ref.read(exportCenterControllerProvider).value;
        final errorMsg = state?.errorMessage ?? l10n.errorGeneric;
        AppFeedback.show(context,
            message: errorMsg, type: AppFeedbackType.error);
      }
    }
  }

  String _getExportTypeName(ReportExportType type, AppLocalizations l10n) {
    switch (type) {
      case ReportExportType.myAttendanceHistory:
        return l10n.exportMyHours;
      case ReportExportType.stationAttendanceSummary:
        return l10n.exportStationAttendanceSummary;
      case ReportExportType.stationEmployeeWorkedHours:
        return l10n.exportStationEmployeeWorkedHours;
      case ReportExportType.dailyAttendanceReport:
        return l10n.exportDailyAttendanceReport;
      case ReportExportType.attendanceCorrectionLedger:
        return l10n.exportAttendanceCorrectionLedger;
      case ReportExportType.publishedSchedule:
        return l10n.exportPublishedSchedule;
      case ReportExportType.employeeDirectory:
        return l10n.exportEmployeeDirectory;
      case ReportExportType.availabilityOverview:
        return l10n.exportAvailabilityOverview;
    }
  }

  IconData _getExportTypeIcon(ReportExportType type) {
    switch (type) {
      case ReportExportType.myAttendanceHistory:
        return LucideIcons.userCheck;
      case ReportExportType.stationAttendanceSummary:
        return LucideIcons.trendingUp;
      case ReportExportType.stationEmployeeWorkedHours:
        return LucideIcons.clock;
      case ReportExportType.dailyAttendanceReport:
        return LucideIcons.calendarDays;
      case ReportExportType.attendanceCorrectionLedger:
        return LucideIcons.fileCheck2;
      case ReportExportType.publishedSchedule:
        return LucideIcons.calendar;
      case ReportExportType.employeeDirectory:
        return LucideIcons.users;
      case ReportExportType.availabilityOverview:
        return LucideIcons.calendarClock;
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    final exportStateAsync = ref.watch(exportCenterControllerProvider);
    final isExporting = exportStateAsync.value?.isExporting ?? false;
    final recentExports = exportStateAsync.value?.recentExports ?? [];
    final lastResult = exportStateAsync.value?.lastResult;

    final availableTypes = <ReportExportType>[];
    if (access.isAdmin) {
      availableTypes.addAll(ReportExportType.values);
    } else if (access.canExportStationReports) {
      availableTypes.addAll([
        ReportExportType.stationAttendanceSummary,
        ReportExportType.stationEmployeeWorkedHours,
        ReportExportType.dailyAttendanceReport,
        ReportExportType.publishedSchedule,
        ReportExportType.availabilityOverview,
        ReportExportType.myAttendanceHistory,
      ]);
    } else {
      availableTypes.add(ReportExportType.myAttendanceHistory);
    }

    if (!availableTypes.contains(_selectedType)) {
      _selectedType = availableTypes.first;
    }

    final isWide = MediaQuery.of(context).size.width >= 900;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(exportCenterControllerProvider.notifier).loadExports(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.insetAll16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: l10n.exportCenterTitle,
                      subtitle: l10n.exportCenterSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Expiry & Security Notice Banner
                    Container(
                      padding: AppSpacing.insetAll12,
                      decoration: BoxDecoration(
                        color: AppColors.colorSurfaceBrandSubtle,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.colorSurfaceBrand),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck,
                              color: AppColors.colorTextPrimary, size: 20),
                          const SizedBox(width: AppSpacing.space12),
                          Expanded(
                            child: Text(
                              l10n.exportExpiryNotice,
                              style: typography.bodyMedium.copyWith(
                                color: AppColors.colorTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Main Generator Layout
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildExportTypeSelector(
                                availableTypes, typography, l10n),
                          ),
                          const SizedBox(width: AppSpacing.space16),
                          Expanded(
                            flex: 2,
                            child: _buildFilterAndActionCard(dateFormat,
                                typography, l10n, isExporting, lastResult),
                          ),
                        ],
                      )
                    else ...[
                      _buildExportTypeSelector(
                          availableTypes, typography, l10n),
                      const SizedBox(height: AppSpacing.space16),
                      _buildFilterAndActionCard(dateFormat, typography, l10n,
                          isExporting, lastResult),
                    ],

                    const SizedBox(height: AppSpacing.space24),

                    // Recent Exports Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.history,
                                      size: 20,
                                      color: AppColors.colorActionPrimary),
                                  const SizedBox(width: AppSpacing.space8),
                                  Text(
                                    l10n.exportHistoryTitle,
                                    style: typography.titleMedium.copyWith(
                                      color: AppColors.colorTextPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon:
                                    const Icon(LucideIcons.refreshCw, size: 18),
                                onPressed: () => ref
                                    .read(
                                        exportCenterControllerProvider.notifier)
                                    .loadExports(),
                                tooltip: l10n.dialogCancel,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          if (recentExports.isEmpty)
                            Padding(
                              padding: AppSpacing.insetAll24,
                              child: Center(
                                child: Text(
                                  l10n.exportHistoryEmpty,
                                  style: typography.bodyMedium.copyWith(
                                    color: AppColors.colorTextMuted,
                                  ),
                                ),
                              ),
                            )
                          else
                            _buildExportsList(
                                recentExports, typography, l10n, isWide),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportTypeSelector(List<ReportExportType> types,
      AppTypography typography, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.exportCenterTitle,
            style: typography.titleMedium.copyWith(
              color: AppColors.colorTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.space8),
            itemBuilder: (context, index) {
              final type = types[index];
              final isSelected = _selectedType == type;
              return InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: AppRadius.borderMd,
                child: Container(
                  padding: AppSpacing.insetAll12,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.colorSurfaceBrandSubtle
                        : AppColors.colorSurfaceBase,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.colorActionPrimary
                          : AppColors.colorBorderSubtle,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.colorActionPrimary
                              : AppColors.colorSurfaceMuted,
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Icon(
                          _getExportTypeIcon(type),
                          size: 18,
                          color: isSelected
                              ? AppColors.colorTextInverse
                              : AppColors.colorTextMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: Text(
                          _getExportTypeName(type, l10n),
                          style: typography.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.colorActionPrimary
                                : AppColors.colorTextPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(LucideIcons.checkCircle2,
                            size: 18, color: AppColors.colorActionPrimary),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndActionCard(
    DateFormat dateFormat,
    AppTypography typography,
    AppLocalizations l10n,
    bool isExporting,
    ExportGenerationResult? lastResult,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.navReports,
            style: typography.titleMedium.copyWith(
              color: AppColors.colorTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),

          // Date Range Display & Quick Presets
          Text(
            '${dateFormat.format(_dateFrom)} — ${dateFormat.format(_dateTo)}',
            style: typography.titleSmall.copyWith(
              color: AppColors.colorActionPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Wrap(
            spacing: AppSpacing.space6,
            runSpacing: AppSpacing.space6,
            children: [
              _buildPresetChip(l10n.exportPreset7Days,
                  () => _selectDatePreset(7), typography),
              _buildPresetChip(l10n.exportPreset30Days,
                  () => _selectDatePreset(30), typography),
              _buildPresetChip(l10n.exportPresetThisMonth,
                  () => _selectDatePreset(0), typography),
              _buildPresetChip(l10n.exportPresetLastMonth,
                  () => _selectDatePreset(-1), typography),
              OutlinedButton.icon(
                onPressed: () => _pickDateRange(context),
                icon: const Icon(LucideIcons.calendar, size: 14),
                label: Text(l10n.exportPresetCustom),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),

          // Format Selector
          Text(
            l10n.exportFormatLabel,
            style: typography.caption.copyWith(color: AppColors.colorTextMuted),
          ),
          const SizedBox(height: AppSpacing.space8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(child: Text(l10n.exportFormatCsv)),
                  selected: _selectedFormat == ExportFormat.csv,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFormat = ExportFormat.csv);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: ChoiceChip(
                  label: Center(child: Text(l10n.exportFormatPdf)),
                  selected: _selectedFormat == ExportFormat.pdf,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFormat = ExportFormat.pdf);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),

          // Primary Generation Action
          AppButton(
            label:
                isExporting ? l10n.exportGenerating : l10n.exportButtonGenerate,
            icon: isExporting ? null : LucideIcons.fileSpreadsheet,
            isLoading: isExporting,
            onPressed: isExporting ? null : _handleGenerate,
          ),

          // Last Result Download Button if ready
          if (lastResult != null && lastResult.downloadUrl != null) ...[
            const SizedBox(height: AppSpacing.space12),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(exportCenterControllerProvider.notifier)
                  .downloadExistingExport(lastResult.exportId),
              icon: const Icon(LucideIcons.downloadCloud, size: 16),
              label: Text(l10n.exportDownloadButton),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(
      String label, VoidCallback onTap, AppTypography typography) {
    return ActionChip(
      label: Text(label, style: typography.caption),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space6, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildExportsList(List<ReportExportItem> exports,
      AppTypography typography, AppLocalizations l10n, bool isWide) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exports.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.colorBorderSubtle),
      itemBuilder: (context, index) {
        final item = exports[index];
        final isExpired = item.isExpired;
        final sizeKb = (item.fileSizeBytes ?? 0) / 1024;

        return Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.space4, horizontal: AppSpacing.space4),
            leading: CircleAvatar(
              backgroundColor: isExpired
                  ? AppColors.colorSurfaceMuted
                  : (item.status.isCompleted
                      ? AppColors.colorStatusSuccessSubtle
                      : AppColors.colorStatusDangerSubtle),
              child: Icon(
                isExpired
                    ? LucideIcons.clockAlert
                    : (item.format == ExportFormat.pdf
                        ? LucideIcons.fileText
                        : LucideIcons.fileSpreadsheet),
                size: 20,
                color: isExpired
                    ? AppColors.colorTextMuted
                    : (item.status.isCompleted
                        ? AppColors.colorStatusSuccess
                        : AppColors.colorStatusDanger),
              ),
            ),
            title: Text(
              _getExportTypeName(item.exportType, l10n),
              style: typography.bodyStrong.copyWith(
                color: isExpired
                    ? AppColors.colorTextMuted
                    : AppColors.colorTextPrimary,
              ),
            ),
            subtitle: Text(
              '${dateFormat.format(item.createdAt)} • ${item.rowCount ?? 0} rows • ${sizeKb.toStringAsFixed(1)} KB',
              style:
                  typography.caption.copyWith(color: AppColors.colorTextMuted),
            ),
            trailing: isExpired
                ? Chip(
                    label: Text(l10n.exportStatusExpired,
                        style: typography.caption),
                    backgroundColor: AppColors.colorSurfaceMuted,
                    visualDensity: VisualDensity.compact,
                  )
                : IconButton(
                    icon: const Icon(LucideIcons.download,
                        size: 20, color: AppColors.colorActionPrimary),
                    tooltip: l10n.exportDownloadButton,
                    onPressed: () => ref
                        .read(exportCenterControllerProvider.notifier)
                        .downloadExistingExport(item.id),
                  ),
          ),
        );
      },
    );
  }
}
