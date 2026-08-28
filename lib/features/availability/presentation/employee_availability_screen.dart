import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_progress_indicator.dart';
import '../../../core/design_system/components/app_segmented_control.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../../stations/domain/station_membership.dart';
import 'widgets/period_management_dialog.dart';
import '../domain/availability_submission.dart';
import 'employee_availability_provider.dart';

class EmployeeAvailabilityScreen extends ConsumerWidget {
  const EmployeeAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(employeeAvailabilityProvider);
    final notifier = ref.read(employeeAvailabilityProvider.notifier);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.inset16,
            child: Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.space16),
                  child: AppSkeleton(height: 120.0),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final activeMembership = ref.watch(activeMembershipProvider);
    final isManagerOrAdmin = activeMembership?.role == StationRole.admin ||
        activeMembership?.role == StationRole.shiftManager;

    final period = state.period;
    if (period == null) {
      final isHebrew = Localizations.localeOf(context).languageCode == 'he';
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: isManagerOrAdmin
                    ? l10n.managerAvailabilityTitle
                    : l10n.availabilityTitle,
                subtitle: isManagerOrAdmin
                    ? l10n.managerAvailabilitySubtitle
                    : l10n.availabilitySubtitle,
                actions: [
                  if (isManagerOrAdmin)
                    AppButton(
                      label: l10n.managerCreatePeriod,
                      icon: LucideIcons.plus,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => const PeriodManagementDialog(),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: AppEmptyState(
                  title: l10n.availabilityNoPeriodTitle,
                  description: isManagerOrAdmin
                      ? (isHebrew
                          ? 'טרם נפתחה תקופת זמינות לשבוע זה. בתור מנהל, באפשרותך ליצור ולפתוח תקופה חדשה כעת.'
                          : 'No active availability period for this week. As an administrator, you can create and open a new period now.')
                      : l10n.availabilityNoPeriodDesc,
                  icon: isManagerOrAdmin
                      ? LucideIcons.calendarPlus
                      : LucideIcons.calendarOff,
                  actionLabel:
                      isManagerOrAdmin ? l10n.managerCreatePeriod : null,
                  onAction: isManagerOrAdmin
                      ? () => showDialog<void>(
                            context: context,
                            builder: (ctx) => const PeriodManagementDialog(),
                          )
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final localeName = Localizations.localeOf(context).toString();
    final weekStartStr =
        DateFormat.MMMd(localeName).format(period.weekStartDate);
    final weekEndStr = DateFormat.MMMd(localeName).format(period.weekEndDate);
    final deadlineStr =
        DateFormat.yMMMd(localeName).add_jm().format(period.submissionDeadline);

    final submissionStatus = state.submission?.submissionStatus ??
        AvailabilitySubmissionStatus.notStarted;
    final isSubmitted =
        submissionStatus == AvailabilitySubmissionStatus.submitted;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: l10n.availabilityTitle,
              subtitle: '$weekStartStr – $weekEndStr',
              actions: [
                if (state.isSavingDraft)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14.0,
                        height: 14.0,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0, color: AppColors.colorTextMuted),
                      ),
                      const SizedBox(width: AppSpacing.space6),
                      Text(l10n.availabilitySavingDraft,
                          style: typography.caption
                              .copyWith(color: AppColors.colorTextMuted)),
                    ],
                  )
                else if (state.saveSuccess)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.check,
                          size: 14.0, color: AppColors.colorSuccess),
                      const SizedBox(width: AppSpacing.space4),
                      Text(l10n.availabilityDraftSaved,
                          style: typography.caption
                              .copyWith(color: AppColors.colorSuccess)),
                    ],
                  ),
              ],
            ),

            // Top Status & Progress Bar
            Padding(
              padding: AppSpacing.insetHorizontal16,
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
                        Wrap(
                          spacing: AppSpacing.space8,
                          runSpacing: AppSpacing.space4,
                          children: [
                            AppStatusBadge(
                              label: isSubmitted
                                  ? l10n.availabilityStatusSubmitted
                                  : (state.answeredSlots > 0
                                      ? l10n.availabilityStatusDraft
                                      : l10n.availabilityStatusNotStarted),
                              variant: isSubmitted
                                  ? AppBadgeVariant.success
                                  : (state.answeredSlots > 0
                                      ? AppBadgeVariant.warning
                                      : AppBadgeVariant.neutral),
                            ),
                            if (!period.isOpen)
                              AppStatusBadge(
                                label: l10n.availabilityStatusClosed,
                                variant: AppBadgeVariant.danger,
                              ),
                          ],
                        ),
                        Text(
                          l10n.availabilityProgress(
                              state.answeredSlots, state.totalSlots),
                          style: typography.caption
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppLinearProgress(
                      value: state.progress,
                      height: 8.0,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      children: [
                        const Icon(LucideIcons.clock,
                            size: 14.0, color: AppColors.colorTextMuted),
                        const SizedBox(width: AppSpacing.space6),
                        Expanded(
                          child: Text(
                            l10n.availabilityDeadlineNotice(deadlineStr),
                            style: typography.caption
                                .copyWith(color: AppColors.colorTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (isSubmitted && period.isOpen) ...[
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        l10n.availabilityEditNotice,
                        style: typography.caption
                            .copyWith(color: AppColors.colorBrandCrimson),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space12),

            // Operational Days List
            Expanded(
              child: ListView.builder(
                padding: AppSpacing.insetHorizontal16,
                itemCount: period.operationalDays.length,
                itemBuilder: (context, dayIndex) {
                  final dayDate = period.operationalDays[dayIndex];
                  final dayName = DateFormat.EEEE(localeName).format(dayDate);
                  final dayFormatted =
                      DateFormat.MMMd(localeName).format(dayDate);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space16),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day Header with Bulk Actions
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.space8,
                            runSpacing: AppSpacing.space8,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dayName,
                                      style: typography.titleMedium.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  Text(dayFormatted,
                                      style: typography.caption.copyWith(
                                          color: AppColors.colorTextMuted)),
                                ],
                              ),
                              if (period.isOpen)
                                Wrap(
                                  spacing: AppSpacing.space4,
                                  runSpacing: AppSpacing.space4,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(LucideIcons.checkCheck,
                                          size: 14.0,
                                          color: AppColors.colorSuccess),
                                      label: Text(
                                        l10n.availabilityAllDayAvailable,
                                        style: typography.caption.copyWith(
                                            color: AppColors.colorSuccess,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () => notifier
                                          .setDayAvailability(dayDate, true),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(LucideIcons.x,
                                          size: 14.0,
                                          color: AppColors.colorError),
                                      label: Text(
                                        l10n.availabilityAllDayUnavailable,
                                        style: typography.caption.copyWith(
                                            color: AppColors.colorError,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () => notifier
                                          .setDayAvailability(dayDate, false),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          const Divider(color: AppColors.colorBorderSubtle),
                          const SizedBox(height: AppSpacing.space8),

                          // Dynamic Shift Rows
                          ...period.templates.map((template) {
                            final slotState =
                                state.getSlotState(dayDate, template.id);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.space8),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 420.0;

                                  final infoWidget = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: AppSpacing.space6,
                                        runSpacing: AppSpacing.space2,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(template.name,
                                              style: typography.bodyStrong),
                                          if (template.isCrossMidnight) ...[
                                            const Icon(LucideIcons.moon,
                                                size: 12.0,
                                                color: AppColors
                                                    .colorBrandCrimson),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.space2),
                                      Text(
                                        template.formatTimeRange(),
                                        style: typography.caption.copyWith(
                                          fontFamily: 'monospace',
                                          color: AppColors.colorTextMuted,
                                        ),
                                      ),
                                    ],
                                  );

                                  final controlWidget =
                                      AppSegmentedControl<bool>(
                                    selectedValue: slotState,
                                    segments: [
                                      AppSegment<bool>(
                                        value: true,
                                        label: l10n.availabilityAvailable,
                                        icon: LucideIcons.check,
                                        activeColor: AppColors.colorBrandYellow,
                                      ),
                                      AppSegment<bool>(
                                        value: false,
                                        label: l10n.availabilityUnavailable,
                                        icon: LucideIcons.x,
                                        activeColor:
                                            AppColors.colorSurfaceSubtle,
                                      ),
                                    ],
                                    onValueChanged: (val) {
                                      if (period.isOpen) {
                                        notifier.toggleSlot(
                                            dayDate, template.id, val);
                                      }
                                    },
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        infoWidget,
                                        const SizedBox(
                                            height: AppSpacing.space8),
                                        controlWidget,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: infoWidget),
                                      controlWidget,
                                    ],
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Sticky Submit Area
            if (period.isOpen)
              Container(
                padding: AppSpacing.inset16,
                decoration: const BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  border: Border(
                      top: BorderSide(
                          color: AppColors.colorBorderSubtle, width: 1.0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!state.isComplete)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.space8),
                        child: Text(
                          'Answer all ${state.totalSlots} slots to enable submission (${state.totalSlots - state.answeredSlots} remaining)',
                          style: typography.caption
                              .copyWith(color: AppColors.colorTextMuted),
                        ),
                      ),
                    AppButton(
                      label: l10n.availabilitySubmitButton,
                      isFullWidth: true,
                      size: AppButtonSize.large,
                      icon: LucideIcons.send,
                      isLoading: state.isSubmitting,
                      onPressed: state.isComplete
                          ? () async {
                              final ok = await notifier.submit();
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.availabilitySubmittedConfirmation(
                                          '$weekStartStr – $weekEndStr'),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
