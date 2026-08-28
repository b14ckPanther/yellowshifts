import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/shift_template.dart';
import '../shift_templates_provider.dart';

class ShiftTemplateDialog extends ConsumerStatefulWidget {
  final ShiftTemplate? template;

  const ShiftTemplateDialog({super.key, this.template});

  @override
  ConsumerState<ShiftTemplateDialog> createState() =>
      _ShiftTemplateDialogState();
}

class _ShiftTemplateDialogState extends ConsumerState<ShiftTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _codeController = TextEditingController(text: widget.template?.code ?? '');
    _startTime =
        widget.template?.startTime ?? const TimeOfDay(hour: 7, minute: 0);
    _endTime =
        widget.template?.endTime ?? const TimeOfDay(hour: 15, minute: 30);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isCrossMidnight {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return startMinutes > endMinutes;
  }

  double get _durationHours {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    var endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes < startMinutes) endMinutes += 24 * 60;
    return (endMinutes - startMinutes) / 60.0;
  }

  Future<void> _pickTime(bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.colorBrandYellow,
                onPrimary: AppColors.colorTextPrimary,
                surface: AppColors.colorSurfaceRaised,
                onSurface: AppColors.colorTextPrimary,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime.hour == _endTime.hour &&
        _startTime.minute == _endTime.minute) {
      setState(() {
        _errorMessage = 'Shift duration cannot be zero hours.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(shiftTemplatesProvider.notifier);
      if (widget.template == null) {
        await notifier.createTemplate(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty
              ? null
              : _codeController.text.trim(),
          startTime: _startTime,
          endTime: _endTime,
        );
      } else {
        await notifier.updateTemplate(
          templateId: widget.template!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty
              ? null
              : _codeController.text.trim(),
          startTime: _startTime,
          endTime: _endTime,
          sortOrder: widget.template!.sortOrder,
          isActive: widget.template!.isActive,
        );
      }

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

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.template != null;

    String formatTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
                    Text(
                      isEditing
                          ? l10n.shiftsEditDialogTitle
                          : l10n.shiftsCreateDialogTitle,
                      style: typography.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20.0),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),

                // Name Field
                AppTextField(
                  label: l10n.shiftsNameLabel,
                  hint: l10n.shiftsNameHint,
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Shift name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.space16),

                // Code Field
                AppTextField(
                  label: l10n.shiftsCodeLabel,
                  hint: l10n.shiftsCodeHint,
                  controller: _codeController,
                ),
                const SizedBox(height: AppSpacing.space20),

                // Time Pickers Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.shiftsStartTime,
                              style: typography.caption.copyWith(
                                  color: AppColors.colorTextSecondary)),
                          const SizedBox(height: AppSpacing.space6),
                          InkWell(
                            onTap: () => _pickTime(true),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space12,
                                  vertical: AppSpacing.space12),
                              decoration: BoxDecoration(
                                color: AppColors.colorSurfaceBase,
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall),
                                border: Border.all(
                                    color: AppColors.colorBorderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatTime(_startTime),
                                    style: typography.bodyStrong
                                        .copyWith(fontFamily: 'monospace'),
                                  ),
                                  const Icon(LucideIcons.clock,
                                      size: 16.0,
                                      color: AppColors.colorTextMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.shiftsEndTime,
                              style: typography.caption.copyWith(
                                  color: AppColors.colorTextSecondary)),
                          const SizedBox(height: AppSpacing.space6),
                          InkWell(
                            onTap: () => _pickTime(false),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space12,
                                  vertical: AppSpacing.space12),
                              decoration: BoxDecoration(
                                color: AppColors.colorSurfaceBase,
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall),
                                border: Border.all(
                                    color: AppColors.colorBorderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatTime(_endTime),
                                    style: typography.bodyStrong
                                        .copyWith(fontFamily: 'monospace'),
                                  ),
                                  const Icon(LucideIcons.clock,
                                      size: 16.0,
                                      color: AppColors.colorTextMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),

                // Duration & Cross-Midnight Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space12,
                      vertical: AppSpacing.space8),
                  decoration: BoxDecoration(
                    color: AppColors.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCrossMidnight ? LucideIcons.moon : LucideIcons.sun,
                        size: 16.0,
                        color: _isCrossMidnight
                            ? AppColors.colorBrandCrimson
                            : AppColors.colorTextSecondary,
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          _isCrossMidnight
                              ? '${_durationHours.toStringAsFixed(1)} hrs • ${l10n.shiftsCrossMidnight}'
                              : '${_durationHours.toStringAsFixed(1)} hrs',
                          style: typography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isCrossMidnight
                                ? AppColors.colorBrandCrimson
                                : AppColors.colorTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      label: 'Cancel',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    AppButton(
                      label: l10n.shiftsSaveButton,
                      isLoading: _isLoading,
                      onPressed: _save,
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
