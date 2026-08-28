import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_filter_chip.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../domain/availability_period.dart';
import '../domain/availability_submission.dart';
import '../domain/availability_matrix.dart';
import 'active_period_provider.dart';
import 'manager_availability_provider.dart';
import 'widgets/period_management_dialog.dart';

class ManagerAvailabilityScreen extends ConsumerWidget {
  const ManagerAvailabilityScreen({super.key});

  void _openCreatePeriodDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const PeriodManagementDialog(),
    );
  }

  String _getPeriodStatusLabel(
      AvailabilityPeriodStatus status, AppLocalizations l10n) {
    switch (status) {
      case AvailabilityPeriodStatus.open:
        return l10n.statusOpen.toUpperCase();
      case AvailabilityPeriodStatus.closed:
        return l10n.statusClosed.toUpperCase();
      case AvailabilityPeriodStatus.draft:
        return l10n.statusDraft.toUpperCase();
    }
  }

  String _getSubmissionStatusLabel(
      AvailabilitySubmissionStatus status, AppLocalizations l10n) {
    switch (status) {
      case AvailabilitySubmissionStatus.submitted:
        return l10n.statusSubmitted.toUpperCase();
      case AvailabilitySubmissionStatus.draft:
        return l10n.statusDraft.toUpperCase();
      case AvailabilitySubmissionStatus.notStarted:
        return l10n.statusNotStarted.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final periodsAsync = ref.watch(availabilityPeriodsListProvider);
    final filter = ref.watch(managerAvailabilityFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: l10n.managerAvailabilityTitle,
              subtitle: l10n.managerAvailabilitySubtitle,
              actions: [
                AppButton(
                  label: l10n.managerCreatePeriod,
                  icon: LucideIcons.plus,
                  onPressed: () => _openCreatePeriodDialog(context),
                ),
              ],
            ),
            Expanded(
              child: periodsAsync.when(
                loading: () => Padding(
                  padding: AppSpacing.inset16,
                  child: Column(
                    children: List.generate(
                      4,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.space12),
                        child: AppSkeleton(height: 100.0),
                      ),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: AppSpacing.inset24,
                  child: Center(
                    child: Text(
                      'Failed to load operational periods: $err',
                      style: typography.bodyMedium
                          .copyWith(color: AppColors.colorError),
                    ),
                  ),
                ),
                data: (periods) {
                  if (periods.isEmpty) {
                    final isHebrew =
                        Localizations.localeOf(context).languageCode == 'he';
                    return AppEmptyState(
                      title: isHebrew
                          ? 'אין תקופות זמינות'
                          : 'No Availability Periods',
                      description: isHebrew
                          ? 'צור תקופת זמינות שבועית כדי להתחיל באיסוף זמינות העובדים.'
                          : 'Create a weekly period to begin collecting workforce availability.',
                      actionLabel: l10n.managerCreatePeriod,
                      icon: LucideIcons.plus,
                      onAction: () => _openCreatePeriodDialog(context),
                    );
                  }

                  // Find selected or default most recent period
                  final activePeriod = periods.firstWhere(
                    (p) => p.id == filter.periodId,
                    orElse: () => periods.first,
                  );

                  return _buildPeriodDetailView(
                    context,
                    ref,
                    activePeriod,
                    periods,
                    l10n,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDetailView(
    BuildContext context,
    WidgetRef ref,
    AvailabilityPeriod period,
    List<AvailabilityPeriod> allPeriods,
    AppLocalizations l10n,
  ) {
    const typography = AppTypography();
    final controller = ref.read(managerAvailabilityControllerProvider);
    final localeName = Localizations.localeOf(context).toString();
    final filter = ref.watch(managerAvailabilityFilterProvider);
    final matrixAsync = ref.watch(managerAvailabilityMatrixProvider(period.id));

    final weekStartStr =
        DateFormat.MMMd(localeName).format(period.weekStartDate);
    final weekEndStr = DateFormat.MMMd(localeName).format(period.weekEndDate);
    final deadlineStr =
        DateFormat.yMMMd(localeName).add_jm().format(period.submissionDeadline);

    final bannerCard = Padding(
      padding: AppSpacing.insetHorizontal16,
      child: AppCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 450.0;

            final infoBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$weekStartStr – $weekEndStr',
                      style: typography.titleMedium
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    AppStatusBadge(
                      label: _getPeriodStatusLabel(period.status, l10n),
                      variant: period.isOpen
                          ? AppBadgeVariant.success
                          : (period.isDraft
                              ? AppBadgeVariant.warning
                              : AppBadgeVariant.neutral),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  l10n.availabilityDeadlineInfo(
                      deadlineStr, period.templates.length),
                  style: typography.caption
                      .copyWith(color: AppColors.colorTextMuted),
                ),
              ],
            );

            final actionButtons = Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space8,
              children: [
                if (period.isDraft)
                  AppButton(
                    label: l10n.managerOpenPeriod,
                    icon: LucideIcons.play,
                    size: AppButtonSize.small,
                    onPressed: () => controller.openPeriod(period.id),
                  ),
                if (period.isOpen)
                  AppButton(
                    label: l10n.managerClosePeriod,
                    icon: LucideIcons.square,
                    variant: AppButtonVariant.destructive,
                    size: AppButtonSize.small,
                    onPressed: () => controller.closePeriod(period.id),
                  ),
                if (period.isClosed)
                  AppButton(
                    label: l10n.managerReopenPeriod,
                    icon: LucideIcons.rotateCcw,
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.small,
                    onPressed: () {
                      final futureDeadline =
                          DateTime.now().add(const Duration(days: 3));
                      controller.reopenPeriod(period.id, futureDeadline);
                    },
                  ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoBlock,
                  const SizedBox(height: AppSpacing.space12),
                  actionButtons,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: infoBlock),
                const SizedBox(width: AppSpacing.space12),
                actionButtons,
              ],
            );
          },
        ),
      ),
    );

    final kpiSection = matrixAsync.when(
      loading: () => const Padding(
        padding: AppSpacing.insetHorizontal16,
        child: AppSkeleton(height: 72.0),
      ),
      error: (_, __) => const SizedBox(),
      data: (matrix) {
        if (matrix == null) return const SizedBox();
        final m = matrix.metrics;

        return Padding(
          padding: AppSpacing.insetHorizontal16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Expanded(
                      child: _buildKpiTile(l10n.managerKpiEligible,
                          m.eligibleEmployees.toString(), null)),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                      child: _buildKpiTile(
                          l10n.managerKpiSubmitted,
                          m.submittedEmployees.toString(),
                          AppColors.colorSuccess)),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                      child: _buildKpiTile(l10n.managerKpiDraft,
                          m.draftEmployees.toString(), AppColors.colorWarning)),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                      child: _buildKpiTile(
                          l10n.managerKpiNotStarted,
                          m.notStartedEmployees.toString(),
                          AppColors.colorTextMuted)),
                ],
              );
            },
          ),
        );
      },
    );

    final filterSection = Padding(
      padding: AppSpacing.insetHorizontal16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            hint: l10n.employeesSearchHint,
            prefixIcon: LucideIcons.search,
            onChanged: (val) {
              ref.read(managerAvailabilityFilterProvider.notifier).state =
                  filter.copyWith(searchQuery: val);
            },
          ),
          const SizedBox(height: AppSpacing.space8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppFilterChip(
                  label: l10n.managerFilterAll,
                  isSelected: filter.statusFilter == null,
                  onSelected: (_) {
                    ref.read(managerAvailabilityFilterProvider.notifier).state =
                        filter.copyWith(statusFilter: null);
                  },
                ),
                const SizedBox(width: AppSpacing.space6),
                AppFilterChip(
                  label: l10n.managerFilterSubmitted,
                  isSelected: filter.statusFilter == 'SUBMITTED',
                  onSelected: (_) {
                    ref.read(managerAvailabilityFilterProvider.notifier).state =
                        filter.copyWith(statusFilter: 'SUBMITTED');
                  },
                ),
                const SizedBox(width: AppSpacing.space6),
                AppFilterChip(
                  label: l10n.managerFilterDraft,
                  isSelected: filter.statusFilter == 'DRAFT',
                  onSelected: (_) {
                    ref.read(managerAvailabilityFilterProvider.notifier).state =
                        filter.copyWith(statusFilter: 'DRAFT');
                  },
                ),
                const SizedBox(width: AppSpacing.space6),
                AppFilterChip(
                  label: l10n.managerFilterNotStarted,
                  isSelected: filter.statusFilter == 'NOT_STARTED',
                  onSelected: (_) {
                    ref.read(managerAvailabilityFilterProvider.notifier).state =
                        filter.copyWith(statusFilter: 'NOT_STARTED');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final isDesktop = MediaQuery.sizeOf(context).width >= 1024.0;

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bannerCard,
          const SizedBox(height: AppSpacing.space12),
          kpiSection,
          const SizedBox(height: AppSpacing.space12),
          filterSection,
          const SizedBox(height: AppSpacing.space12),
          Expanded(
            child: matrixAsync.when(
              loading: () => Padding(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.space12),
                      child: AppSkeleton(height: 60.0),
                    ),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load matrix: $err',
                  style: typography.bodyMedium
                      .copyWith(color: AppColors.colorError),
                ),
              ),
              data: (matrix) {
                if (matrix == null || matrix.members.isEmpty) {
                  return Center(child: Text(l10n.noEmployeeRecordsFound));
                }
                return _buildDesktopMatrixTable(context, period, matrix, l10n);
              },
            ),
          ),
        ],
      );
    }

    // Mobile / Tablet Unified Scroll
    return matrixAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.space24),
        children: [
          bannerCard,
          const SizedBox(height: AppSpacing.space12),
          kpiSection,
          const SizedBox(height: AppSpacing.space12),
          filterSection,
          const SizedBox(height: AppSpacing.space12),
          Padding(
            padding: AppSpacing.insetHorizontal16,
            child: Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.space12),
                  child: AppSkeleton(height: 80.0),
                ),
              ),
            ),
          ),
        ],
      ),
      error: (err, _) => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.space24),
        children: [
          bannerCard,
          const SizedBox(height: AppSpacing.space12),
          kpiSection,
          const SizedBox(height: AppSpacing.space12),
          filterSection,
          const SizedBox(height: AppSpacing.space12),
          Center(
            child: Text(
              'Failed to load matrix: $err',
              style:
                  typography.bodyMedium.copyWith(color: AppColors.colorError),
            ),
          ),
        ],
      ),
      data: (matrix) {
        final members = matrix?.members ?? [];
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.space24),
          itemCount: 4 + (members.isEmpty ? 1 : members.length),
          itemBuilder: (context, index) {
            if (index == 0) return bannerCard;
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space12),
                child: kpiSection,
              );
            }
            if (index == 2) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space12),
                child: filterSection,
              );
            }
            if (index == 3) {
              return const SizedBox(height: AppSpacing.space12);
            }

            if (members.isEmpty) {
              return Padding(
                padding: AppSpacing.insetAll24,
                child: Center(child: Text(l10n.noEmployeeRecordsFound)),
              );
            }

            final memberIndex = index - 4;
            final member = members[memberIndex];
            final answeredCount = member.entries.length;
            final totalCount = period.requiredSlotCount;

            return Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.space16,
                right: AppSpacing.space16,
                bottom: AppSpacing.space12,
              ),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.space8,
                      runSpacing: AppSpacing.space8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(name: member.fullName, size: 36.0),
                            const SizedBox(width: AppSpacing.space12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.fullName,
                                    style: typography.bodyStrong),
                                Text(
                                  member.role,
                                  style: typography.caption.copyWith(
                                      color: AppColors.colorTextMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        AppStatusBadge(
                          label: _getSubmissionStatusLabel(
                              member.submissionStatus, l10n),
                          variant: member.submissionStatus ==
                                  AvailabilitySubmissionStatus.submitted
                              ? AppBadgeVariant.success
                              : (member.submissionStatus ==
                                      AvailabilitySubmissionStatus.draft
                                  ? AppBadgeVariant.warning
                                  : AppBadgeVariant.neutral),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      l10n.availabilitySlotsAnswered(answeredCount, totalCount),
                      style: typography.caption
                          .copyWith(color: AppColors.colorTextSecondary),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiTile(String label, String value, Color? color) {
    const typography = AppTypography();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12, vertical: AppSpacing.space8),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.colorBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: typography.caption
                  .copyWith(color: AppColors.colorTextMuted, fontSize: 11.0)),
          const SizedBox(height: AppSpacing.space2),
          Text(value,
              style: typography.titleMedium
                  .copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildDesktopMatrixTable(
      BuildContext context,
      AvailabilityPeriod period,
      AvailabilityMatrix matrix,
      AppLocalizations l10n) {
    const typography = AppTypography();
    final localeName = Localizations.localeOf(context).toString();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: AppSpacing.insetHorizontal16,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.colorSurfaceSubtle),
          columnSpacing: 16.0,
          horizontalMargin: 12.0,
          columns: [
            DataColumn(
              label: Text(l10n.employeesColName, style: typography.bodyStrong),
            ),
            DataColumn(
              label:
                  Text(l10n.employeesColStatus, style: typography.bodyStrong),
            ),
            // 7 Days Columns
            ...List.generate(7, (dayOffset) {
              final dayDate =
                  period.weekStartDate.add(Duration(days: dayOffset));
              final dayHeader = DateFormat.E(localeName).format(dayDate);
              final dateHeader = DateFormat.Md(localeName).format(dayDate);
              return DataColumn(
                label: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayHeader,
                        style: typography.caption
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(dateHeader,
                        style: typography.caption.copyWith(
                            fontSize: 10.0, color: AppColors.colorTextMuted)),
                  ],
                ),
              );
            }),
          ],
          rows: matrix.members.map((member) {
            return DataRow(
              cells: [
                // Employee cell
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(name: member.fullName, size: 28.0),
                      const SizedBox(width: AppSpacing.space8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.fullName,
                              style: typography.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            member.employeeCode ?? member.role,
                            style: typography.caption.copyWith(
                                fontSize: 10.0,
                                color: AppColors.colorTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge cell
                DataCell(
                  AppStatusBadge(
                    label: _getSubmissionStatusLabel(
                        member.submissionStatus, l10n),
                    variant: member.submissionStatus ==
                            AvailabilitySubmissionStatus.submitted
                        ? AppBadgeVariant.success
                        : (member.submissionStatus ==
                                AvailabilitySubmissionStatus.draft
                            ? AppBadgeVariant.warning
                            : AppBadgeVariant.neutral),
                  ),
                ),
                // 7 Day availability slot cells
                ...List.generate(7, (dayOffset) {
                  final dayDate =
                      period.weekStartDate.add(Duration(days: dayOffset));
                  final dateStr =
                      '${dayDate.year.toString().padLeft(4, '0')}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';

                  return DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: period.templates.map((template) {
                        final key = '${dateStr}_${template.id}';
                        final isAvailable = member.entries[key];

                        Color bg = AppColors.colorSurfaceSubtle;
                        Color fg = AppColors.colorTextMuted;
                        String symbol = '—';

                        if (isAvailable == true) {
                          bg = AppColors.colorBrandYellow;
                          fg = AppColors.colorTextPrimary;
                          symbol =
                              template.code != null && template.code!.isNotEmpty
                                  ? template.code![0].toUpperCase()
                                  : '✓';
                        } else if (isAvailable == false) {
                          bg = AppColors.colorSurfaceMuted;
                          fg = AppColors.colorTextMuted;
                          symbol = '✕';
                        }

                        return Container(
                          width: 22.0,
                          height: 22.0,
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            symbol,
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
