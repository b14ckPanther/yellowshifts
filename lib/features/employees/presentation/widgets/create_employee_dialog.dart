import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/motion/app_motion.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stations/domain/station_membership.dart';

import '../employee_creation_controller.dart';

class CreateEmployeeDialog extends ConsumerStatefulWidget {
  const CreateEmployeeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateEmployeeDialog(),
    );
  }

  @override
  ConsumerState<CreateEmployeeDialog> createState() =>
      _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends ConsumerState<CreateEmployeeDialog> {
  int _currentStep = 0;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeCodeController = TextEditingController();
  StationRole _selectedRole = StationRole.employee;
  EmployeeCreationResult? _successResult;
  String? _validationError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _employeeCodeController.dispose();
    super.dispose();
  }

  void _validateAndProceed() {
    setState(() => _validationError = null);
    if (_currentStep == 0) {
      if (_firstNameController.text.trim().isEmpty) {
        setState(() => _validationError = 'Please enter a first name.');
        return;
      }
      if (_lastNameController.text.trim().isEmpty) {
        setState(() => _validationError = 'Please enter a last name.');
        return;
      }
      if (_phoneController.text.trim().isEmpty &&
          _emailController.text.trim().isEmpty) {
        setState(() => _validationError =
            'Please provide either a phone number or an email address.');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      _handleSubmit();
    }
  }

  Future<void> _handleSubmit() async {
    try {
      final result = await ref
          .read(employeeCreationControllerProvider.notifier)
          .createEmployee(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            email: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            role: _selectedRole,
            employeeCode: _employeeCodeController.text.trim().isNotEmpty
                ? _employeeCodeController.text.trim()
                : null,
          );

      setState(() {
        _successResult = result;
        _currentStep = 2;
      });
    } catch (e) {
      // Error handled by controller state
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final creationState = ref.watch(employeeCreationControllerProvider);

    return Dialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540.0),
        child: Padding(
          padding: AppSpacing.insetAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _successResult != null
                              ? l10n.createEmployeeSuccessTitle
                              : l10n.createEmployeeTitle,
                          style: typography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          _successResult != null
                              ? l10n.createEmployeeSuccessDesc
                              : l10n.createEmployeeSubtitle,
                          style: typography.caption
                              .copyWith(color: AppColors.colorTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_successResult == null)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20.0),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space20),

              // Step Indicator (if in creation flow)
              if (_successResult == null) ...[
                Row(
                  children: [
                    _buildStepIndicator(0, l10n.createEmployeeStepIdentity),
                    const SizedBox(width: AppSpacing.space8),
                    Container(
                        width: 24.0,
                        height: 1.0,
                        color: AppColors.colorBorderMedium),
                    const SizedBox(width: AppSpacing.space8),
                    _buildStepIndicator(1, l10n.createEmployeeStepRole),
                  ],
                ),
                const SizedBox(height: AppSpacing.space20),
              ],

              // Error banner if any
              if (_validationError != null || creationState.error != null) ...[
                Container(
                  padding: AppSpacing.insetAll12,
                  decoration: BoxDecoration(
                    color: AppColors.colorStatusDangerSubtle,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                        color: AppColors.colorStatusDanger.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle,
                          size: 16.0, color: AppColors.colorStatusDanger),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          _validationError ??
                              ErrorLocalizer.localize(
                                  creationState.error, l10n),
                          style: typography.caption.copyWith(
                            color: AppColors.colorStatusDanger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),
              ],

              // Step 0: Identity
              if (_currentStep == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.createEmployeeFirstName,
                        hint: 'David',
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: AppTextField(
                        label: l10n.createEmployeeLastName,
                        hint: 'Cohen',
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                AppTextField(
                  label: l10n.createEmployeePhone,
                  hint: '+972-50-1234567',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(LucideIcons.phone,
                      size: 16.0, color: AppColors.colorTextMuted),
                ),
                const SizedBox(height: AppSpacing.space12),
                AppTextField(
                  label: l10n.createEmployeeEmail,
                  hint: 'david@company.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(LucideIcons.mail,
                      size: 16.0, color: AppColors.colorTextMuted),
                ),
                const SizedBox(height: AppSpacing.space12),
                AppTextField(
                  label: l10n.createEmployeeCode,
                  hint: 'EMP-042',
                  controller: _employeeCodeController,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(LucideIcons.badge,
                      size: 16.0, color: AppColors.colorTextMuted),
                ),
              ],

              // Step 1: Role Selection
              if (_currentStep == 1) ...[
                Text(
                  l10n.createEmployeeRoleLabel,
                  style: typography.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.space12),
                _buildRoleOption(
                  role: StationRole.employee,
                  title: l10n.roleEmployee,
                  description:
                      'Standard station member. Accesses personal schedule and clock-in.',
                  icon: LucideIcons.user,
                ),
                const SizedBox(height: AppSpacing.space8),
                _buildRoleOption(
                  role: StationRole.shiftManager,
                  title: l10n.roleShiftManager,
                  description:
                      'Operational supervisor. Manages shift execution and attendance.',
                  icon: LucideIcons.userCheck,
                ),
              ],

              // Step 2: Success / Temporary Credentials Output
              if (_currentStep == 2 && _successResult != null) ...[
                if (_successResult!.isNewUser &&
                    _successResult!.temporaryPassword != null) ...[
                  Container(
                    padding: AppSpacing.insetAll16,
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceBrandSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                          color: AppColors.colorTextBrand.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createEmployeeTempPassword,
                          style: typography.caption.copyWith(
                            color: AppColors.colorTextBrand,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        SelectableText(
                          _successResult!.temporaryPassword!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.colorTextPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        Row(
                          children: [
                            AppButton(
                              label: l10n.createEmployeeCopyPassword,
                              icon: LucideIcons.copy,
                              size: AppButtonSize.small,
                              variant: AppButtonVariant.primary,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        'YellowShifts Login:\nUser: ${_successResult!.email ?? _phoneController.text}\nTemporary Password: ${_successResult!.temporaryPassword}',
                                  ),
                                );
                                AppFeedback.show(context,
                                    message: l10n.createEmployeeCopiedToast);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert,
                          size: 16.0, color: AppColors.colorStatusWarning),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          l10n.createEmployeeSecurityNotice,
                          style: typography.caption
                              .copyWith(color: AppColors.colorTextMuted),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: AppSpacing.insetAll16,
                    decoration: BoxDecoration(
                      color: AppColors.colorStatusSuccessSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                          color: AppColors.colorStatusSuccess.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.checkCircle2,
                            size: 24.0, color: AppColors.colorStatusSuccess),
                        const SizedBox(width: AppSpacing.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Existing Account Assigned',
                                style: typography.bodyStrong.copyWith(
                                    color: AppColors.colorTextPrimary),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                'This user is already registered on YellowShifts. Their new station membership is active.',
                                style: typography.caption.copyWith(
                                    color: AppColors.colorTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: AppSpacing.space24),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep == 1)
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child:
                          Text(l10n.commonCancel, style: typography.labelLarge),
                    ),
                  if (_currentStep == 0)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child:
                          Text(l10n.commonCancel, style: typography.labelLarge),
                    ),
                  const SizedBox(width: AppSpacing.space12),
                  if (_currentStep < 2)
                    AppButton(
                      label: _currentStep == 0
                          ? 'Next'
                          : l10n.createEmployeeSubmit,
                      isLoading: creationState.isLoading,
                      onPressed: _validateAndProceed,
                    ),
                  if (_currentStep == 2)
                    AppButton(
                      label: l10n.commonClose,
                      onPressed: () {
                        ref
                            .read(employeeCreationControllerProvider.notifier)
                            .reset();
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title) {
    const typography = AppTypography();
    final isActive = _currentStep >= stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22.0,
          height: 22.0,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.colorSurfaceBrand
                : AppColors.colorSurfaceMuted,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${stepIndex + 1}',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? AppColors.colorTextBrand
                  : AppColors.colorTextMuted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space6),
        Text(
          title,
          style: typography.caption.copyWith(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? AppColors.colorTextPrimary
                : AppColors.colorTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required StationRole role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    const typography = AppTypography();
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        padding: AppSpacing.insetAll12,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.colorSurfaceBrandSubtle
              : AppColors.colorSurfaceRaised,
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: isSelected
                ? AppColors.colorTextBrand
                : AppColors.colorBorderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.colorSurfaceBrand
                    : AppColors.colorSurfaceMuted,
                borderRadius: AppRadius.borderSm,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18.0,
                color: isSelected
                    ? AppColors.colorTextBrand
                    : AppColors.colorTextSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.bodyStrong
                        .copyWith(color: AppColors.colorTextPrimary),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    description,
                    style: typography.caption
                        .copyWith(color: AppColors.colorTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 20.0,
              color: isSelected
                  ? AppColors.colorTextBrand
                  : AppColors.colorTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
