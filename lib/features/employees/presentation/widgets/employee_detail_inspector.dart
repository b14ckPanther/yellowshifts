import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_avatar.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_dialog.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_status_badge.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../core/permissions/station_access_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stations/domain/station_membership.dart';
import '../../domain/employee_details.dart';
import '../employee_directory_provider.dart';
import 'edit_employee_dialog.dart';

class EmployeeDetailInspector extends ConsumerStatefulWidget {
  final EmployeeDetails employee;
  final VoidCallback? onClose;

  const EmployeeDetailInspector({
    super.key,
    required this.employee,
    this.onClose,
  });

  @override
  ConsumerState<EmployeeDetailInspector> createState() =>
      _EmployeeDetailInspectorState();
}

class _EmployeeDetailInspectorState
    extends ConsumerState<EmployeeDetailInspector> {
  bool _isLoadingAction = false;

  Future<void> _handleRoleChange(StationRole newRole) async {
    final l10n = AppLocalizations.of(context)!;
    if (newRole == widget.employee.role) return;

    setState(() => _isLoadingAction = true);
    try {
      await ref
          .read(employeeDirectoryProvider.notifier)
          .updateRole(widget.employee.membershipId, newRole);

      if (mounted) {
        AppFeedback.show(context,
            message: l10n.employeeEditSuccessToast,
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        final localizedError = ErrorLocalizer.localize(e, l10n);
        AppFeedback.show(context,
            message: localizedError, type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleStatusToggle(MembershipStatus newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingAction = true);
    try {
      await ref
          .read(employeeDirectoryProvider.notifier)
          .updateStatus(widget.employee.membershipId, newStatus);

      if (mounted) {
        AppFeedback.show(context,
            message: l10n.employeeEditSuccessToast,
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        final localizedError = ErrorLocalizer.localize(e, l10n);
        AppFeedback.show(context,
            message: localizedError, type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.employeeResetPasswordTitle,
        subtitle: l10n.employeeResetPasswordConfirm(widget.employee.fullName),
        actions: [
          AppButton(
            label: l10n.dialogCancel,
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(width: AppSpacing.space8),
          AppButton(
            label: l10n.employeeResetPasswordGenerate,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingAction = true);
    try {
      final tempPassword = await ref
          .read(employeeDirectoryProvider.notifier)
          .resetPassword(widget.employee.userId);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AppDialog(
            title: l10n.employeeResetPasswordSuccessTitle,
            subtitle:
                l10n.employeeResetPasswordSuccessDesc(widget.employee.fullName),
            content: Container(
              padding: AppSpacing.insetAll16,
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBase,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: Column(
                children: [
                  SelectableText(
                    tempPassword,
                    style: typography.headlineSmall.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.colorTextBrand,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    l10n.employeeResetPasswordNotice,
                    style: typography.caption
                        .copyWith(color: AppColors.colorTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: l10n.copyPassword,
                icon: LucideIcons.copy,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tempPassword));
                  AppFeedback.show(context, message: l10n.passwordCopied);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: AppSpacing.space8),
              AppButton(
                label: l10n.closeButton,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizedError = ErrorLocalizer.localize(e, l10n);
        AppFeedback.show(context,
            message: localizedError, type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleRevokeSessions() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingAction = true);
    try {
      await ref
          .read(employeeDirectoryProvider.notifier)
          .revokeSessions(widget.employee.userId);
      if (mounted) {
        AppFeedback.show(context,
            message: l10n.employeeRevokeSessionsSuccess,
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        final localizedError = ErrorLocalizer.localize(e, l10n);
        AppFeedback.show(context,
            message: localizedError, type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    final emp = widget.employee;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        border: Border(
            left: BorderSide(color: AppColors.colorBorderSubtle, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header
          Container(
            padding: AppSpacing.insetAll20,
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.colorBorderSubtle, width: 1.0)),
            ),
            child: Row(
              children: [
                AppAvatar(name: emp.fullName, size: 48.0),
                const SizedBox(width: AppSpacing.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.fullName,
                        style: typography.titleMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Row(
                        children: [
                          _buildRoleBadge(emp.role, l10n),
                          const SizedBox(width: AppSpacing.space8),
                          _buildStatusBadge(emp.status, l10n),
                        ],
                      ),
                    ],
                  ),
                ),
                if (access.canEditEmployeeProfiles)
                  IconButton(
                    icon: const Icon(LucideIcons.pencil, size: 18.0),
                    tooltip: l10n.employeeEditAction,
                    onPressed: () => EditEmployeeDialog.show(context, emp),
                  ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20.0),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.insetAll20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact & Profile Section
                  Text(
                    l10n.inspectorContactSection,
                    style: typography.caption.copyWith(
                      color: AppColors.colorTextMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  if (emp.email != null && emp.email!.isNotEmpty) ...[
                    _buildDetailRow(
                      icon: LucideIcons.mail,
                      label: l10n.employeeEditEmailLabel,
                      value: emp.email!,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                  ],
                  _buildDetailRow(
                    icon: LucideIcons.phone,
                    label: l10n.employeesColPhone,
                    value: emp.phone ?? l10n.notProvided,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  _buildDetailRow(
                    icon: LucideIcons.badge,
                    label: l10n.employeesColCode,
                    value: emp.employeeCode ?? l10n.noCodeAssigned,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  _buildDetailRow(
                    icon: LucideIcons.calendar,
                    label: l10n.joinedStationLabel,
                    value:
                        '${emp.joinedAt.day}/${emp.joinedAt.month}/${emp.joinedAt.year}',
                  ),

                  // Privileged Actions (Admin Only)
                  if (access.canManageMembershipRoles) ...[
                    const SizedBox(height: AppSpacing.space24),
                    const Divider(color: AppColors.colorBorderSubtle),
                    const SizedBox(height: AppSpacing.space16),

                    // Station Role Assignment
                    Text(
                      l10n.inspectorMembershipSection,
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    if (emp.role == StationRole.admin) ...[
                      Text(l10n.inspectorRoleChange,
                          style: typography.bodyStrong),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        l10n.roleStationManager,
                        style: typography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        l10n.platformAdminRoleReadonlyHint,
                        style: typography.caption
                            .copyWith(color: AppColors.colorTextSecondary),
                      ),
                    ] else ...[
                      Text(l10n.inspectorRoleChange,
                          style: typography.bodyStrong),
                      const SizedBox(height: AppSpacing.space8),
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
                          child: DropdownButton<StationRole>(
                            value: emp.role,
                            isExpanded: true,
                            icon:
                                const Icon(LucideIcons.chevronDown, size: 18.0),
                            items: [
                              DropdownMenuItem(
                                value: StationRole.employee,
                                child: Text(l10n.roleEmployee,
                                    style: typography.bodyMedium),
                              ),
                              DropdownMenuItem(
                                value: StationRole.shiftManager,
                                child: Text(l10n.roleShiftManager,
                                    style: typography.bodyMedium),
                              ),
                            ],
                            onChanged: _isLoadingAction
                                ? null
                                : (newRole) {
                                    if (newRole != null) {
                                      _handleRoleChange(newRole);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.space24),
                    const Divider(color: AppColors.colorBorderSubtle),
                    const SizedBox(height: AppSpacing.space16),

                    // Security & Access Actions
                    Text(
                      l10n.inspectorSecuritySection,
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppButton(
                      label: l10n.inspectorResetPassword,
                      variant: AppButtonVariant.outline,
                      icon: LucideIcons.keyRound,
                      isFullWidth: true,
                      isLoading: _isLoadingAction,
                      onPressed: _handleResetPassword,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppButton(
                      label: l10n.inspectorRevokeSessions,
                      variant: AppButtonVariant.secondary,
                      icon: LucideIcons.shieldAlert,
                      isFullWidth: true,
                      isLoading: _isLoadingAction,
                      onPressed: _handleRevokeSessions,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    if (emp.role != StationRole.admin)
                      AppButton(
                        label: emp.isActive
                            ? l10n.inspectorDeactivate
                            : l10n.inspectorReactivate,
                        variant: emp.isActive
                            ? AppButtonVariant.destructive
                            : AppButtonVariant.primary,
                        icon: emp.isActive
                            ? LucideIcons.userX
                            : LucideIcons.userCheck,
                        isFullWidth: true,
                        isLoading: _isLoadingAction,
                        onPressed: () {
                          _handleStatusToggle(
                            emp.isActive
                                ? MembershipStatus.inactive
                                : MembershipStatus.active,
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: AppSpacing.space24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    const typography = AppTypography();
    return Row(
      children: [
        Icon(icon, size: 16.0, color: AppColors.colorTextMuted),
        const SizedBox(width: AppSpacing.space8),
        Text(
          '$label: ',
          style: typography.bodyMedium
              .copyWith(color: AppColors.colorTextSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: typography.bodyStrong
                .copyWith(color: AppColors.colorTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(StationRole role, AppLocalizations l10n) {
    switch (role) {
      case StationRole.admin:
        return AppStatusBadge(
          label: l10n.roleAdmin,
          variant: AppBadgeVariant.brand,
          icon: LucideIcons.shieldCheck,
        );
      case StationRole.shiftManager:
        return AppStatusBadge(
          label: l10n.roleShiftManager,
          variant: AppBadgeVariant.info,
          icon: LucideIcons.userCheck,
        );
      case StationRole.employee:
        return AppStatusBadge(
          label: l10n.roleEmployee,
          variant: AppBadgeVariant.neutral,
          icon: LucideIcons.user,
        );
    }
  }

  Widget _buildStatusBadge(MembershipStatus status, AppLocalizations l10n) {
    switch (status) {
      case MembershipStatus.active:
        return AppStatusBadge(
          label: l10n.statusActive,
          variant: AppBadgeVariant.success,
        );
      case MembershipStatus.inactive:
        return AppStatusBadge(
          label: l10n.statusInactive,
          variant: AppBadgeVariant.warning,
        );
      case MembershipStatus.suspended:
        return AppStatusBadge(
          label: l10n.statusSuspended,
          variant: AppBadgeVariant.danger,
        );
    }
  }
}
