import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../domain/models/work_schedule.dart';
import '../controllers/scheduling_controller.dart';

class SchedulePublishModal extends ConsumerStatefulWidget {
  final WorkSchedule schedule;

  const SchedulePublishModal({super.key, required this.schedule});

  static Future<void> show(BuildContext context,
      {required WorkSchedule schedule}) {
    return showDialog(
      context: context,
      builder: (ctx) => SchedulePublishModal(schedule: schedule),
    );
  }

  @override
  ConsumerState<SchedulePublishModal> createState() =>
      _SchedulePublishModalState();
}

class _SchedulePublishModalState extends ConsumerState<SchedulePublishModal> {
  bool _confirmWarnings = false;
  bool _isSubmitting = false;

  Future<void> _handlePublish() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(schedulingControllerProvider.notifier).publishSchedule(
            scheduleId: widget.schedule.id,
            expectedVersion: widget.schedule.version,
            confirmWarnings: _confirmWarnings,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.colorStatusSuccess,
            content: Text('הלוח השבועי פורסם בהצלחה והפך לרשמי!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusDanger,
            content: Text('שגיאה בפרסום הלוח: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final validationAsync =
        ref.watch(scheduleValidationProvider(widget.schedule.id));

    return Dialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        side: const BorderSide(color: AppColors.colorBorderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520.0, maxHeight: 680.0),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space8),
                    decoration: BoxDecoration(
                      color: AppColors.colorBrandYellow.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Icon(LucideIcons.send,
                        color: AppColors.colorBrandYellow, size: 24.0),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('פרסום לוח משמרות שבועי',
                            style: typography.titleLarge),
                        Text('אישור והפיכת הלוח לרשמי עבור עובדי התחנה',
                            style: typography.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              const Divider(),
              // Validation Body
              Expanded(
                child: validationAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                  error: (err, _) => Center(
                    child: Text('שגיאה בבדיקת תקינות הלוח: $err',
                        style: typography.bodyMedium),
                  ),
                  data: (val) {
                    final hasHardErrors = val.hardErrors.isNotEmpty;
                    final hasWarnings = val.warnings.isNotEmpty;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Coverage Summary Cards
                          Row(
                            children: [
                              _buildMetricCard('משמרות',
                                  '${val.summary.totalShifts}', typography),
                              const SizedBox(width: AppSpacing.space8),
                              _buildMetricCard(
                                  'מאוישות',
                                  '${val.summary.fullyStaffedShifts}',
                                  typography,
                                  color: AppColors.colorStatusSuccess),
                              const SizedBox(width: AppSpacing.space8),
                              _buildMetricCard(
                                  'חסרות',
                                  '${val.summary.understaffedShifts}',
                                  typography,
                                  color: val.summary.understaffedShifts > 0
                                      ? AppColors.colorStatusWarning
                                      : AppColors.colorTextMuted),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          // Hard Errors Section
                          if (hasHardErrors) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space12),
                              decoration: BoxDecoration(
                                color: AppColors.colorStatusDanger
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium),
                                border: Border.all(
                                    color: AppColors.colorStatusDanger),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.circleAlert,
                                          size: 16.0,
                                          color: AppColors.colorStatusDanger),
                                      const SizedBox(width: AppSpacing.space6),
                                      Text(
                                        'שגיאות קריטיות (${val.hardErrors.length}) — חוסמות פרסום',
                                        style: typography.bodyStrong.copyWith(
                                          color: AppColors.colorStatusDanger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space8),
                                  ...val.hardErrors.map(
                                    (e) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4.0),
                                      child: Text('• ${e.message}',
                                          style: typography.caption),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space16),
                          ],
                          // Warnings Section
                          if (hasWarnings) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space12),
                              decoration: BoxDecoration(
                                color: AppColors.colorStatusWarning
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium),
                                border: Border.all(
                                    color: AppColors.colorStatusWarning),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.triangleAlert,
                                          size: 16.0,
                                          color: AppColors.colorStatusWarning),
                                      const SizedBox(width: AppSpacing.space6),
                                      Text(
                                        'אזהרות איוש וזמינות (${val.warnings.length})',
                                        style: typography.bodyStrong.copyWith(
                                          color: AppColors.colorStatusWarning,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space8),
                                  ...val.warnings.map(
                                    (w) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4.0),
                                      child: Text('• ${w.message}',
                                          style: typography.caption),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space16),
                            // Confirmation Checkbox for Warnings
                            CheckboxListTile(
                              value: _confirmWarnings,
                              onChanged: (val) => setState(
                                  () => _confirmWarnings = val ?? false),
                              title: Text(
                                'אני מאשר פרסום הלוח למרות האזהרות הקיימות',
                                style: typography.bodyStrong,
                              ),
                              activeColor: AppColors.colorBrandYellow,
                              checkColor: AppColors.colorTextPrimary,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.space8),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('ביטול'),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  validationAsync.maybeWhen(
                    data: (val) {
                      final canPublish = val.canPublish &&
                          (val.warnings.isEmpty || _confirmWarnings);

                      return ElevatedButton(
                        onPressed: (_isSubmitting || !canPublish)
                            ? null
                            : _handlePublish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colorBrandYellow,
                          foregroundColor: AppColors.colorTextPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space20,
                            vertical: AppSpacing.space12,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18.0,
                                height: 18.0,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : const Text('פרסם לוח עכשיו'),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, AppTypography typography,
      {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space12),
        decoration: BoxDecoration(
          color: AppColors.colorSurfaceBase,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.colorBorderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: typography.caption),
            const SizedBox(height: 4.0),
            Text(
              value,
              style: typography.titleMedium.copyWith(
                color: color ?? AppColors.colorTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
