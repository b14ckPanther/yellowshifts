import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../../availability/presentation/active_period_provider.dart';
import '../../availability/domain/availability_period.dart';
import '../data/scheduling_repository.dart';
import '../domain/models/work_schedule.dart';
import 'controllers/scheduling_controller.dart';
import 'widgets/app_day_strip.dart';
import 'widgets/shift_card.dart';
import 'widgets/schedule_publish_modal.dart';

class ManagerScheduleScreen extends ConsumerStatefulWidget {
  const ManagerScheduleScreen({super.key});

  @override
  ConsumerState<ManagerScheduleScreen> createState() =>
      _ManagerScheduleScreenState();
}

class _ManagerScheduleScreenState extends ConsumerState<ManagerScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = ref.read(selectedScheduleWeekProvider);
  }

  void _changeWeek(int deltaWeeks) {
    final cur = ref.read(selectedScheduleWeekProvider);
    final nextWeek = cur.add(Duration(days: deltaWeeks * 7));
    ref.read(selectedScheduleWeekProvider.notifier).state = nextWeek;
    setState(() {
      _selectedDate = nextWeek;
    });
  }

  Future<void> _handleCreateSchedule() async {
    final activeStation = ref.read(activeMembershipProvider)?.station;
    if (activeStation == null) return;

    final weekStart = ref.read(selectedScheduleWeekProvider);
    final period = await ref
        .read(availabilityPeriodsListProvider.future)
        .then((periods) => periods.cast<AvailabilityPeriod?>().firstWhere(
              (p) =>
                  p != null &&
                  p.weekStartDate.year == weekStart.year &&
                  p.weekStartDate.month == weekStart.month &&
                  p.weekStartDate.day == weekStart.day,
              orElse: () => null,
            ))
        .catchError((_) => null);

    if (period == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.colorStatusWarning,
            content: Text(
                'לא נמצאה תקופת זמינות לשבוע זה. יש לפתוח תקופת זמינות תחילה בהגדרות.'),
          ),
        );
      }
      return;
    }

    try {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.createWorkSchedule(period.id);
      ref.invalidate(activeScheduleProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.colorStatusSuccess,
            content: Text('לוח משמרות שבועי נוצר בהצלחה מתוך תבניות הזמינות!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusDanger,
            content: Text('שגיאה ביצירת הלוח: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final activeMembership = ref.watch(activeMembershipProvider);
    final weekStart = ref.watch(selectedScheduleWeekProvider);
    final scheduleAsync = ref.watch(activeScheduleProvider);
    final stationName = activeMembership?.station?.name ?? 'תחנה';

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Toolbar: Week Navigator & Status Badge
            _buildWeekToolbar(
                context, weekStart, scheduleAsync.valueOrNull, typography),
            // Main Responsive Body
            Expanded(
              child: scheduleAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
                error: (err, _) => Center(
                  child: Text('שגיאה בטעינת הלוח: $err',
                      style: typography.bodyMedium),
                ),
                data: (schedule) {
                  if (schedule == null) {
                    return Padding(
                      padding: AppSpacing.insetAll24,
                      child: AppEmptyState(
                        title: 'טרם נוצר לוח משמרות לשבוע זה',
                        description:
                            'ניתן ליצור לוח חדש מתוך תבניות תקופת הזמינות של $stationName.',
                        icon: LucideIcons.calendarPlus,
                        actionLabel: 'צור לוח משמרות לשבוע זה',
                        onAction: _handleCreateSchedule,
                      ),
                    );
                  }

                  return AdaptiveBuilder(
                    builder: (context, sizeClass) {
                      switch (sizeClass) {
                        case AppSizeClass.compact:
                          return _buildCompactView(schedule, typography);
                        case AppSizeClass.medium:
                          return _buildMediumView(schedule, typography);
                        case AppSizeClass.expanded:
                          return _buildExpandedView(schedule, typography);
                      }
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

  Widget _buildWeekToolbar(BuildContext context, DateTime weekStart,
      WorkSchedule? schedule, AppTypography typography) {
    final endDate = weekStart.add(const Duration(days: 6));
    final weekStr =
        '${weekStart.day}/${weekStart.month} – ${endDate.day}/${endDate.month}';

    Color statusColor = AppColors.colorStatusWarning;
    String statusText = 'טיוטה (v${schedule?.version ?? 1})';
    if (schedule?.isPublished == true) {
      statusColor = AppColors.colorStatusSuccess;
      statusText = 'לוח רשמי מפורסם (v${schedule?.version ?? 1})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.colorBorderSubtle, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Week Switcher Controls
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 20.0),
            tooltip: 'שבוע קודם',
            onPressed: () => _changeWeek(-1),
          ),
          InkWell(
            onTap: () {
              final initial = ref.read(selectedScheduleWeekProvider);
              showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              ).then((picked) {
                if (picked != null) {
                  final activeMembership = ref.read(activeMembershipProvider);
                  final weekStartDay =
                      activeMembership?.station?.weekStart ?? 0;
                  final clean = DateTime(picked.year, picked.month, picked.day);
                  final diff = (clean.weekday % 7 - weekStartDay + 7) % 7;
                  final adjusted = clean.subtract(Duration(days: diff));
                  ref.read(selectedScheduleWeekProvider.notifier).state =
                      adjusted;
                  setState(() => _selectedDate = adjusted);
                }
              });
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
                vertical: AppSpacing.space4,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 16.0),
                  const SizedBox(width: AppSpacing.space6),
                  Text(
                    weekStr,
                    style: typography.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 20.0),
            tooltip: 'שבוע הבא',
            onPressed: () => _changeWeek(1),
          ),
          const Spacer(),
          // Status Pill
          if (schedule != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space10,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                statusText,
                style: typography.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            if (schedule.isDraft)
              ElevatedButton.icon(
                onPressed: () =>
                    SchedulePublishModal.show(context, schedule: schedule),
                icon: const Icon(LucideIcons.send, size: 14.0),
                label: const Text('פרסם לוח'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorBrandYellow,
                  foregroundColor: AppColors.colorTextPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                    vertical: AppSpacing.space8,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // Compact Mobile View: Day Strip + Shifts for Selected Day
  Widget _buildCompactView(WorkSchedule schedule, AppTypography typography) {
    final dayShifts = schedule.shifts
        .where((s) =>
            s.operationalDate.year == _selectedDate.year &&
            s.operationalDate.month == _selectedDate.month &&
            s.operationalDate.day == _selectedDate.day)
        .toList();

    return Column(
      children: [
        AppDayStrip(
          weekStartDate: schedule.weekStartDate,
          selectedDate: _selectedDate,
          onDateSelected: (d) => setState(() => _selectedDate = d),
          schedule: schedule,
        ),
        // Staffing Progress Bar
        _buildStaffingProgressBar(schedule, typography),
        // Shift Cards List
        Expanded(
          child: dayShifts.isEmpty
              ? const Center(
                  child: Text('אין משמרות מוגדרות ליום זה'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  itemCount: dayShifts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.space12),
                  itemBuilder: (context, index) {
                    final shift = dayShifts[index];
                    return ShiftCard(
                      shift: shift,
                      currentScheduleVersion: schedule.version,
                      isPublished: schedule.isPublished,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Medium Tablet View
  Widget _buildMediumView(WorkSchedule schedule, AppTypography typography) {
    return _buildCompactView(schedule, typography);
  }

  // Expanded Desktop View: 7-Day Operational Board
  Widget _buildExpandedView(WorkSchedule schedule, AppTypography typography) {
    return Column(
      children: [
        _buildStaffingProgressBar(schedule, typography),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (dayIndex) {
              final dayDate =
                  schedule.weekStartDate.add(Duration(days: dayIndex));
              final dayShifts = schedule.shifts
                  .where((s) =>
                      s.operationalDate.year == dayDate.year &&
                      s.operationalDate.month == dayDate.month &&
                      s.operationalDate.day == dayDate.day)
                  .toList();

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppColors.colorBorderSubtle,
                        width: dayIndex < 6 ? 1.0 : 0.0,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Day Header
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        color: AppColors.colorSurfaceRaised,
                        child: Text(
                          _getExpandedDayHeader(dayDate),
                          textAlign: TextAlign.center,
                          style: typography.bodyStrong,
                        ),
                      ),
                      const Divider(height: 1.0),
                      // Day Shifts
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.space8),
                          itemCount: dayShifts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.space8),
                          itemBuilder: (context, idx) {
                            return ShiftCard(
                              shift: dayShifts[idx],
                              currentScheduleVersion: schedule.version,
                              isPublished: schedule.isPublished,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffingProgressBar(
      WorkSchedule schedule, AppTypography typography) {
    final pct = schedule.staffingCoveragePercent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space6,
      ),
      color: AppColors.colorSurfaceRaised.withValues(alpha: 0.5),
      child: Row(
        children: [
          Text(
            'כיסוי איוש שבועי: ${pct.toStringAsFixed(0)}% (${schedule.totalAssignmentsCount} שיבוצים)',
            style: typography.caption,
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: pct / 100.0,
                backgroundColor: AppColors.colorSurfaceBase,
                valueColor: AlwaysStoppedAnimation(
                  pct >= 100.0
                      ? AppColors.colorStatusSuccess
                      : AppColors.colorBrandYellow,
                ),
                minHeight: 6.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getExpandedDayHeader(DateTime date) {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    final name = days[date.weekday % 7];
    return '$name (${date.day}/${date.month})';
  }
}
