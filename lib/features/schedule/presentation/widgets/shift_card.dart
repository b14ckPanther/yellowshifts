import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../domain/models/work_schedule_shift.dart';
import '../../domain/models/shift_assignment.dart';
import '../controllers/scheduling_controller.dart';
import 'candidate_selection_sheet.dart';

class ShiftCard extends ConsumerWidget {
  final WorkScheduleShift shift;
  final int currentScheduleVersion;
  final bool isPublished;

  const ShiftCard({
    super.key,
    required this.shift,
    required this.currentScheduleVersion,
    required this.isPublished,
  });

  Color _getStaffingColor(StaffingState state) {
    switch (state) {
      case StaffingState.fullyStaffed:
        return AppColors.colorStatusSuccess;
      case StaffingState.understaffed:
        return AppColors.colorStatusWarning;
      case StaffingState.overstaffed:
        return AppColors.colorStatusInfo;
    }
  }

  String _getStaffingLabel(StaffingState state) {
    switch (state) {
      case StaffingState.fullyStaffed:
        return 'מאויש מלא';
      case StaffingState.understaffed:
        return 'חסר איוש';
      case StaffingState.overstaffed:
        return 'עודף איוש';
    }
  }

  Future<void> _handleRemoveAssignment(
    BuildContext context,
    WidgetRef ref,
    ShiftAssignment assignment,
  ) async {
    String? changeReason;

    if (isPublished) {
      final textController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.colorSurfaceRaised,
          title: const Text('הסרת עובד מלוח רשמי'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'האם להסיר את ${assignment.fullName} מהמשמרת? יש להזין סיבה:'),
              const SizedBox(height: AppSpacing.space12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'סיבת הסרה...',
                  filled: true,
                  fillColor: AppColors.colorSurfaceBase,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().length >= 3) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('אישור הסרה'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      changeReason = textController.text.trim();
    }

    try {
      await ref.read(schedulingControllerProvider.notifier).removeAssignment(
            assignmentId: assignment.id,
            expectedVersion: currentScheduleVersion,
            changeReason: changeReason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusSuccess,
            content: Text('${assignment.fullName} הוסר מהמשמרת'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusDanger,
            content: Text('שגיאה בהסרת עובד: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final staffingColor = _getStaffingColor(shift.staffingState);
    final staffingLabel = _getStaffingLabel(shift.staffingState);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: shift.staffingState == StaffingState.understaffed
              ? AppColors.colorStatusWarning.withValues(alpha: 0.5)
              : AppColors.colorBorderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Shift Name, Time & Staffing Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.space6,
                      children: [
                        Text(
                          shift.shiftName,
                          style: typography.titleMedium,
                        ),
                        if (shift.isCrossMidnight)
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
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${shift.startTime} – ${shift.endTime}',
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Staffing Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space8,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: staffingColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: staffingColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${shift.assignedStaffCount}/${shift.requiredStaffCount}',
                      style: typography.caption.copyWith(
                        color: staffingColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      staffingLabel,
                      style: typography.caption.copyWith(
                        color: staffingColor,
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          // Assigned Employees Chips & Add Button
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...shift.assignments.map((asgn) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.colorBrandYellow,
                    child: Text(
                      asgn.firstName.isNotEmpty
                          ? asgn.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 10.0,
                        color: AppColors.colorTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    asgn.fullName,
                    style: typography.bodyMedium,
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14.0),
                  onDeleted: () => _handleRemoveAssignment(context, ref, asgn),
                  backgroundColor: asgn.availabilityOverride
                      ? AppColors.colorStatusWarning.withValues(alpha: 0.2)
                      : AppColors.colorSurfaceBase,
                  side: BorderSide(
                    color: asgn.availabilityOverride
                        ? AppColors.colorStatusWarning
                        : AppColors.colorBorderSubtle,
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(LucideIcons.userPlus, size: 14.0),
                label: const Text('הוסף עובד'),
                onPressed: () => CandidateSelectionSheet.show(
                  context,
                  shift: shift,
                  currentScheduleVersion: currentScheduleVersion,
                  isPublished: isPublished,
                ),
                backgroundColor: AppColors.colorSurfaceBrandAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
