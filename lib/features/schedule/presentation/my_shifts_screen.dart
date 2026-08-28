import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../domain/models/my_shift.dart';
import 'controllers/scheduling_controller.dart';

class MyShiftsScreen extends ConsumerWidget {
  const MyShiftsScreen({super.key});

  void _changeWeek(WidgetRef ref, int deltaWeeks) {
    final cur = ref.read(selectedScheduleWeekProvider);
    final nextWeek = cur.add(Duration(days: deltaWeeks * 7));
    ref.read(selectedScheduleWeekProvider.notifier).state = nextWeek;
  }

  String _getDayName(int weekday) {
    const days = [
      'יום ראשון',
      'יום שני',
      'יום שלישי',
      'יום רביעי',
      'יום חמישי',
      'יום שישי',
      'יום שבת'
    ];
    return days[weekday % 7];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final activeMembership = ref.watch(activeMembershipProvider);
    final weekStart = ref.watch(selectedScheduleWeekProvider);
    final myShiftsAsync = ref.watch(myShiftsProvider);
    final stationName = activeMembership?.station?.name ?? 'תחנה';

    final endDate = weekStart.add(const Duration(days: 6));
    final weekStr =
        '${weekStart.day}/${weekStart.month} – ${endDate.day}/${endDate.month}';

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Week Navigator Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
                vertical: AppSpacing.space12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.colorSurfaceRaised,
                border: Border(
                  bottom: BorderSide(
                      color: AppColors.colorBorderSubtle, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, size: 20.0),
                    tooltip: 'שבוע קודם',
                    onPressed: () => _changeWeek(ref, -1),
                  ),
                  Text(
                    'המשמרות שלי — $weekStr',
                    style: typography.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, size: 20.0),
                    tooltip: 'שבוע הבא',
                    onPressed: () => _changeWeek(ref, 1),
                  ),
                ],
              ),
            ),
            // Shifts List or Empty States
            Expanded(
              child: myShiftsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
                error: (err, _) => Center(
                  child: Text('שגיאה בטעינת משמרות: $err',
                      style: typography.bodyMedium),
                ),
                data: (res) {
                  // State 1: No published schedule yet
                  if (!res.hasPublishedSchedule) {
                    return Padding(
                      padding: AppSpacing.insetAll24,
                      child: AppEmptyState(
                        title: 'טרם פורסם לוח משמרות לשבוע זה',
                        description:
                            'מנהל תחנת $stationName עדיין עובד על שיבוץ המשמרות. הלוח יופיע כאן מיד עם פרסומו.',
                        icon: LucideIcons.calendarClock,
                      ),
                    );
                  }

                  // State 2: Published but not assigned
                  if (res.shifts.isEmpty) {
                    return Padding(
                      padding: AppSpacing.insetAll24,
                      child: AppEmptyState(
                        title: 'אין לך משמרות משובצות לשבוע זה',
                        description:
                            'הלוח השבועי הרשמי פורסם, אך לא שובצת למשמרות בשבוע $weekStr.',
                        icon: LucideIcons.calendarCheck,
                      ),
                    );
                  }

                  // State 3: Assigned shifts
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    itemCount: res.shifts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.space12),
                    itemBuilder: (context, index) {
                      final shift = res.shifts[index];
                      return _buildShiftCard(shift, typography);
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

  Widget _buildShiftCard(MyShift shift, AppTypography typography) {
    final dayName = _getDayName(shift.operationalDate.weekday);
    final dateStr =
        '${shift.operationalDate.day}/${shift.operationalDate.month}';
    final hours = shift.plannedDuration.inHours;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: const Border(
          right: BorderSide(color: AppColors.colorBrandYellow, width: 4.0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Column
          Container(
            width: 72.0,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.space8,
              horizontal: AppSpacing.space4,
            ),
            decoration: BoxDecoration(
              color: AppColors.colorSurfaceBase,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.colorBorderSubtle),
            ),
            child: Column(
              children: [
                Text(
                  dayName,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorBrandYellow,
                    fontSize: 10.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  dateStr,
                  style: typography.titleLarge.copyWith(fontSize: 16.0),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space16),
          // Shift Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      shift.shiftName,
                      style: typography.titleMedium.copyWith(fontSize: 17.0),
                    ),
                    if (shift.isCrossMidnight) ...[
                      const SizedBox(width: AppSpacing.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space6,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.colorSurfaceBrandAccent,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          '+1 יום',
                          style: typography.caption.copyWith(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    const Icon(LucideIcons.clock,
                        size: 14.0, color: AppColors.colorTextSecondary),
                    const SizedBox(width: 4.0),
                    Text(
                      '${shift.startTime} – ${shift.endTime} ($hours שעות)',
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin,
                        size: 14.0, color: AppColors.colorTextSecondary),
                    const SizedBox(width: 4.0),
                    Text(
                      shift.stationName,
                      style: typography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
