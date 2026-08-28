import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_dialog.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stations/domain/station_membership.dart';
import '../../domain/employee_details.dart';
import '../employee_directory_provider.dart';

class EditEmployeeDialog extends ConsumerStatefulWidget {
  final EmployeeDetails employee;

  const EditEmployeeDialog({super.key, required this.employee});

  static Future<void> show(
      BuildContext context, EmployeeDetails employee) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditEmployeeDialog(employee: employee),
    );
  }

  @override
  ConsumerState<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends ConsumerState<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _employeeCodeController;

  late StationRole _selectedRole;
  late MembershipStatus _selectedStatus;
  late String _selectedLocale;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _firstNameController = TextEditingController(text: emp.firstName);
    _lastNameController = TextEditingController(text: emp.lastName);
    _emailController = TextEditingController(text: emp.email ?? '');
    _phoneController = TextEditingController(text: emp.phone ?? '');
    _employeeCodeController =
        TextEditingController(text: emp.employeeCode ?? '');
    _selectedRole = emp.role;
    _selectedStatus = emp.status;
    _selectedLocale =
        emp.preferredLocale.isNotEmpty ? emp.preferredLocale : 'he';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(employeeDirectoryProvider.notifier).updateEmployeeProfile(
            userId: widget.employee.userId,
            membershipId: widget.employee.membershipId,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            preferredLocale: _selectedLocale,
            role: _selectedRole,
            status: _selectedStatus,
            employeeCode: _employeeCodeController.text.trim().isNotEmpty
                ? _employeeCodeController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.show(
          context,
          message: l10n.employeeEditSuccessToast,
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final localizedError = ErrorLocalizer.localize(e, l10n);
        AppFeedback.show(
          context,
          message: localizedError,
          type: AppFeedbackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    return AppDialog(
      title: l10n.employeeEditTitle,
      subtitle: l10n.employeeEditSubtitle,
      width: 580.0,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Global Profile Notice
              Container(
                padding: AppSpacing.insetAll12,
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBrandSubtle,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                      color: AppColors.colorBorderSubtle, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.globe,
                        size: 18.0, color: AppColors.colorTextBrand),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Text(
                        l10n.employeeEditGlobalNotice,
                        style: typography.caption.copyWith(
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),

              // First & Last Name Row
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: l10n.employeeEditFirstNameLabel,
                      controller: _firstNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.errorInvalidInput;
                        }
                        if (value.trim().length > 100) {
                          return l10n.errorInvalidInput;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: AppTextField(
                      label: l10n.employeeEditLastNameLabel,
                      controller: _lastNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.errorInvalidInput;
                        }
                        if (value.trim().length > 100) {
                          return l10n.errorInvalidInput;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),

              // Phone & Email Row
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: l10n.employeeEditPhoneLabel,
                      controller: _phoneController,
                      prefixIcon: const Icon(LucideIcons.phone,
                          size: 16.0, color: AppColors.colorTextMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: AppTextField(
                      label: l10n.employeeEditEmailLabel,
                      controller: _emailController,
                      prefixIcon: const Icon(LucideIcons.mail,
                          size: 16.0, color: AppColors.colorTextMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),

              // Preferred Locale Dropdown
              Text(
                l10n.employeeEditLocaleLabel,
                style: typography.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.space6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBase,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: AppColors.colorBorderMedium),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLocale,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 18.0),
                    items: const [
                      DropdownMenuItem(
                          value: 'he', child: Text('עברית (Hebrew)')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedLocale = val);
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space20),

              // Station Scope Notice
              Container(
                padding: AppSpacing.insetAll12,
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                      color: AppColors.colorBorderSubtle, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.building,
                        size: 18.0, color: AppColors.colorTextSecondary),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Text(
                        l10n.employeeEditStationNotice,
                        style: typography.caption.copyWith(
                          color: AppColors.colorTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),

              // Station Role & Status Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.employeeEditRoleLabel,
                            style: typography.bodyStrong),
                        const SizedBox(height: AppSpacing.space6),
                        if (widget.employee.role == StationRole.admin)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space12,
                                vertical: AppSpacing.space12),
                            decoration: BoxDecoration(
                              color: AppColors.colorSurfaceMuted,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                  color: AppColors.colorBorderMedium),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.roleStationManager,
                                    style: typography.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.platformAdminRoleReadonlyHint,
                                  style: typography.caption.copyWith(
                                      color: AppColors.colorTextSecondary),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space12),
                            decoration: BoxDecoration(
                              color: AppColors.colorSurfaceBase,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                  color: AppColors.colorBorderMedium),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<StationRole>(
                                value: _selectedRole,
                                isExpanded: true,
                                icon: const Icon(LucideIcons.chevronDown,
                                    size: 18.0),
                                items: [
                                  DropdownMenuItem(
                                    value: StationRole.employee,
                                    child: Text(l10n.roleEmployee),
                                  ),
                                  DropdownMenuItem(
                                    value: StationRole.shiftManager,
                                    child: Text(l10n.roleShiftManager),
                                  ),
                                ],
                                onChanged: _isSaving
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _selectedRole = val);
                                        }
                                      },
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
                        Text(l10n.employeeEditStatusLabel,
                            style: typography.bodyStrong),
                        const SizedBox(height: AppSpacing.space6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space12),
                          decoration: BoxDecoration(
                            color: AppColors.colorSurfaceBase,
                            borderRadius: AppRadius.borderMd,
                            border:
                                Border.all(color: AppColors.colorBorderMedium),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<MembershipStatus>(
                              value: _selectedStatus,
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown,
                                  size: 18.0),
                              items: [
                                DropdownMenuItem(
                                  value: MembershipStatus.active,
                                  child: Text(l10n.statusActive),
                                ),
                                DropdownMenuItem(
                                  value: MembershipStatus.inactive,
                                  child: Text(l10n.statusInactive),
                                ),
                                DropdownMenuItem(
                                  value: MembershipStatus.suspended,
                                  child: Text(l10n.statusSuspended),
                                ),
                              ],
                              onChanged: (_isSaving ||
                                      widget.employee.role == StationRole.admin)
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() => _selectedStatus = val);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),

              // Employee Code
              AppTextField(
                label: l10n.employeeEditCodeLabel,
                controller: _employeeCodeController,
                prefixIcon: const Icon(LucideIcons.badge,
                    size: 16.0, color: AppColors.colorTextMuted),
              ),
              const SizedBox(height: AppSpacing.space24),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.dialogCancel,
          variant: AppButtonVariant.outline,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSpacing.space8),
        AppButton(
          label: l10n.employeeEditSaveButton,
          variant: AppButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
