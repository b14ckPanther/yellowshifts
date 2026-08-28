import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../domain/models/work_schedule.dart';

class AppDayStrip extends StatelessWidget {
  final DateTime weekStartDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final WorkSchedule? schedule;

  const AppDayStrip({
    super.key,
    required this.weekStartDate,
    required this.selectedDate,
    required this.onDateSelected,
    this.schedule,
  });

  String _getDayName(int weekday) {
    switch (weekday % 7) {
      case 0:
        return 'א׳';
      case 1:
        return 'ב׳';
      case 2:
        return 'ג׳';
      case 3:
        return 'ד׳';
      case 4:
        return 'ה׳';
      case 5:
        return 'ו׳';
      case 6:
        return 'ש׳';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Container(
      height: 76.0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.colorBorderSubtle, width: 1.0),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.space8),
        itemBuilder: (context, index) {
          final dayDate = weekStartDate.add(Duration(days: index));
          final isSelected = dayDate.year == selectedDate.year &&
              dayDate.month == selectedDate.month &&
              dayDate.day == selectedDate.day;

          // Find shifts for this day to compute staffing status dot
          final dayShifts = schedule?.shifts
                  .where((s) =>
                      s.operationalDate.year == dayDate.year &&
                      s.operationalDate.month == dayDate.month &&
                      s.operationalDate.day == dayDate.day)
                  .toList() ??
              [];

          final totalReq =
              dayShifts.fold(0, (acc, s) => acc + s.requiredStaffCount);
          final totalAsgn =
              dayShifts.fold(0, (acc, s) => acc + s.assignedStaffCount);

          Color statusDotColor = Colors.transparent;
          if (dayShifts.isNotEmpty) {
            if (totalAsgn >= totalReq) {
              statusDotColor = AppColors.colorStatusSuccess;
            } else if (totalAsgn > 0) {
              statusDotColor = AppColors.colorStatusWarning;
            } else {
              statusDotColor = AppColors.colorStatusDanger;
            }
          }

          return InkWell(
            onTap: () => onDateSelected(dayDate),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 54.0,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.colorSurfaceBrandAccent
                    : AppColors.colorSurfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: isSelected
                      ? AppColors.colorBrandYellow
                      : AppColors.colorBorderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayName(dayDate.weekday),
                    style: typography.caption.copyWith(
                      color: isSelected
                          ? AppColors.colorTextPrimary
                          : AppColors.colorTextSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '${dayDate.day}',
                    style: typography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.colorTextPrimary
                          : AppColors.colorTextSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: statusDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
