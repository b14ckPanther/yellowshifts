import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import 'active_period_provider.dart';
import 'manager_availability_provider.dart';

class AvailabilityHistoryScreen extends ConsumerWidget {
  const AvailabilityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final periodsAsync = ref.watch(availabilityPeriodsListProvider);
    final localeName = Localizations.localeOf(context).toString();

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(
              title: 'Availability Periods History',
              subtitle:
                  'Browse all operational weekly periods and historical records.',
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
                        child: AppSkeleton(height: 80.0),
                      ),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: AppSpacing.inset24,
                  child: Center(
                    child: Text(
                      'Failed to load period history: $err',
                      style: typography.bodyMedium
                          .copyWith(color: AppColors.colorError),
                    ),
                  ),
                ),
                data: (periods) {
                  if (periods.isEmpty) {
                    return const AppEmptyState(
                      title: 'No Periods Recorded',
                      description:
                          'No weekly availability periods have been configured yet.',
                      icon: LucideIcons.calendarOff,
                    );
                  }

                  return ListView.builder(
                    padding: AppSpacing.insetHorizontal16,
                    itemCount: periods.length,
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final weekStartStr = DateFormat.yMMMd(localeName)
                          .format(period.weekStartDate);
                      final weekEndStr = DateFormat.yMMMd(localeName)
                          .format(period.weekEndDate);
                      final deadlineStr = DateFormat.yMMMd(localeName)
                          .add_jm()
                          .format(period.submissionDeadline);

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.space12),
                        child: AppCard(
                          child: InkWell(
                            onTap: () {
                              ref
                                      .read(managerAvailabilityFilterProvider
                                          .notifier)
                                      .state =
                                  ref
                                      .read(managerAvailabilityFilterProvider)
                                      .copyWith(periodId: period.id);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 44.0,
                                  height: 44.0,
                                  decoration: BoxDecoration(
                                    color: period.isOpen
                                        ? AppColors.colorBrandYellow
                                        : AppColors.colorSurfaceSubtle,
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMedium),
                                  ),
                                  child: Icon(
                                    period.isOpen
                                        ? LucideIcons.calendarCheck
                                        : LucideIcons.calendar,
                                    size: 22.0,
                                    color: AppColors.colorTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: AppSpacing.space8,
                                        runSpacing: AppSpacing.space4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '$weekStartStr – $weekEndStr',
                                            style: typography.bodyStrong
                                                .copyWith(fontSize: 14.0),
                                          ),
                                          AppStatusBadge(
                                            label: period.status.name
                                                .toUpperCase(),
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
                                        'Deadline: $deadlineStr • ${period.templates.length} shifts / day',
                                        style: typography.caption.copyWith(
                                            color: AppColors.colorTextMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.chevronRight,
                                    size: 20.0,
                                    color: AppColors.colorTextMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
