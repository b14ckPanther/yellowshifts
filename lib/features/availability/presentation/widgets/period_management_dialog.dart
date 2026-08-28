import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../../data/availability_repository.dart';
import '../active_period_provider.dart';

class PeriodManagementDialog extends ConsumerStatefulWidget {
  const PeriodManagementDialog({super.key});

  @override
  ConsumerState<PeriodManagementDialog> createState() =>
      _PeriodManagementDialogState();
}

class _PeriodManagementDialogState
    extends ConsumerState<PeriodManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _weekStartDate;
  late DateTime _deadlineDate;
  late TimeOfDay _deadlineTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default next Sunday
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    final nextSunday =
        now.add(Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday));
    _weekStartDate =
        DateTime(nextSunday.year, nextSunday.month, nextSunday.day);

    // Default deadline: Friday before next Sunday at 18:00
    final defaultDeadline = _weekStartDate.subtract(const Duration(days: 2));
    _deadlineDate = DateTime(
        defaultDeadline.year, defaultDeadline.month, defaultDeadline.day);
    _deadlineTime = const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _fullDeadline {
    return DateTime(
      _deadlineDate.year,
      _deadlineDate.month,
      _deadlineDate.day,
      _deadlineTime.hour,
      _deadlineTime.minute,
    );
  }

  Future<void> _pickWeekStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 14)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _weekStartDate = DateTime(picked.year, picked.month, picked.day);
        // Automatically default deadline to 2 days prior
        _deadlineDate = _weekStartDate.subtract(const Duration(days: 2));
      });
    }
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate.isAfter(DateTime.now())
          ? _deadlineDate
          : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _weekStartDate.add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() {
        _deadlineDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deadlineTime,
    );
    if (picked != null) {
      setState(() => _deadlineTime = picked);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fullDeadline.isBefore(DateTime.now())) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMessage = l10n.submissionDeadlineFutureError);
      return;
    }

    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(availabilityRepositoryProvider).createAvailabilityPeriod(
            stationId: stationId,
            weekStartDate: _weekStartDate,
            submissionDeadline: _fullDeadline,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      ref.invalidate(availabilityPeriodsListProvider);
      ref.invalidate(currentAvailabilityPeriodProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    final weekEnd = _weekStartDate.add(const Duration(days: 6));

    return Dialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480.0),
        child: Padding(
          padding: AppSpacing.inset24,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.managerCreatePeriod,
                        style: typography.titleLarge),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20.0),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),

                // Operational Week Picker
                Text(l10n.operationalWeekRange,
                    style: typography.caption
                        .copyWith(color: AppColors.colorTextSecondary)),
                const SizedBox(height: AppSpacing.space6),
                InkWell(
                  onTap: _pickWeekStart,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space12,
                        vertical: AppSpacing.space12),
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceBase,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(color: AppColors.colorBorderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatDate(_weekStartDate)} – ${_formatDate(weekEnd)}',
                          style: typography.bodyStrong
                              .copyWith(fontFamily: 'monospace'),
                        ),
                        const Icon(LucideIcons.calendar,
                            size: 16.0, color: AppColors.colorTextMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),

                // Submission Deadline
                Text(l10n.submissionDeadline,
                    style: typography.caption
                        .copyWith(color: AppColors.colorTextSecondary)),
                const SizedBox(height: AppSpacing.space6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickDeadlineDate,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space12,
                              vertical: AppSpacing.space12),
                          decoration: BoxDecoration(
                            color: AppColors.colorSurfaceBase,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                            border:
                                Border.all(color: AppColors.colorBorderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDate(_deadlineDate),
                                  style: typography.bodyMedium),
                              const Icon(LucideIcons.calendar,
                                  size: 16.0, color: AppColors.colorTextMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickDeadlineTime,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space12,
                              vertical: AppSpacing.space12),
                          decoration: BoxDecoration(
                            color: AppColors.colorSurfaceBase,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                            border:
                                Border.all(color: AppColors.colorBorderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_deadlineTime.hour.toString().padLeft(2, '0')}:${_deadlineTime.minute.toString().padLeft(2, '0')}',
                                style: typography.bodyStrong
                                    .copyWith(fontFamily: 'monospace'),
                              ),
                              const Icon(LucideIcons.clock,
                                  size: 16.0, color: AppColors.colorTextMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),

                // Optional Notes Field
                AppTextField(
                  label: l10n.operationalNotesOptional,
                  hint: l10n.operationalNotesHint,
                  controller: _notesController,
                  maxLines: 2,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    _errorMessage!,
                    style: typography.caption
                        .copyWith(color: AppColors.colorError),
                  ),
                ],

                const SizedBox(height: AppSpacing.space24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: l10n.dialogCancel,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    AppButton(
                      label: l10n.createPeriodAction,
                      isLoading: _isLoading,
                      onPressed: _create,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
