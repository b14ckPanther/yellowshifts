import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_dialog.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/platform_admin_repository.dart';
import '../../domain/platform_station_manager.dart';

class ResetManagerPasswordDialog extends ConsumerStatefulWidget {
  final String stationId;
  final PlatformStationManager manager;

  const ResetManagerPasswordDialog({
    super.key,
    required this.stationId,
    required this.manager,
  });

  static Future<void> show(
    BuildContext context, {
    required String stationId,
    required PlatformStationManager manager,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResetManagerPasswordDialog(
        stationId: stationId,
        manager: manager,
      ),
    );
  }

  @override
  ConsumerState<ResetManagerPasswordDialog> createState() =>
      _ResetManagerPasswordDialogState();
}

class _ResetManagerPasswordDialogState
    extends ConsumerState<ResetManagerPasswordDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscured = true;
  bool _isLoading = false;
  String? _establishedPassword;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    const chars =
        r'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*';
    final rand = Random.secure();
    final buffer = StringBuffer('Ys#');
    for (int i = 0; i < 9; i++) {
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    setState(() {
      _passwordController.text = buffer.toString();
      _isObscured = false;
    });
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    final passwordText = _passwordController.text.trim();

    if (passwordText.isNotEmpty && passwordText.length < 6) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newPassword =
          await ref.read(platformAdminRepositoryProvider).resetManagerPassword(
                stationId: widget.stationId,
                userId: widget.manager.userId,
                newPassword: passwordText.isNotEmpty ? passwordText : null,
              );

      if (mounted) {
        setState(() {
          _establishedPassword =
              newPassword.isNotEmpty ? newPassword : passwordText;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppFeedback.show(
          context,
          message: ErrorLocalizer.localize(e, l10n),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    // Success State
    if (_establishedPassword != null) {
      return AppDialog(
        title: l10n.employeeResetPasswordSuccessTitle,
        subtitle:
            l10n.employeeResetPasswordSuccessDesc(widget.manager.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: AppSpacing.insetAll16,
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBase,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: Column(
                children: [
                  SelectableText(
                    _establishedPassword!,
                    style: typography.headlineSmall.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.colorTextBrand,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  AppButton(
                    label: l10n.copyPassword,
                    icon: LucideIcons.copy,
                    variant: AppButtonVariant.outline,
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _establishedPassword!));
                      AppFeedback.show(context, message: l10n.passwordCopied);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              l10n.employeeResetPasswordNoticeCustom,
              style: typography.caption
                  .copyWith(color: AppColors.colorTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: l10n.closeButton,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // Input / Configuration State
    return AppDialog(
      title: l10n.employeeResetPasswordTitle,
      subtitle: l10n.employeeResetPasswordSubtitle(widget.manager.fullName),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _passwordController,
              label: l10n.employeeResetPasswordCustomLabel,
              hint: l10n.employeeResetPasswordCustomHint,
              obscureText: _isObscured,
              prefixIcon: LucideIcons.lock,
              validator: (val) {
                if (val != null &&
                    val.trim().isNotEmpty &&
                    val.trim().length < 6) {
                  return l10n.employeeResetPasswordMinLengthError;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(LucideIcons.sparkles, size: 16.0),
                label: Text(
                  l10n.employeeResetPasswordGenerateAction,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorActionPrimary,
                  ),
                ),
                onPressed: _isLoading ? null : _generateRandomPassword,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Container(
              padding: AppSpacing.insetAll12,
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBase,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info,
                      size: 16.0, color: AppColors.colorTextMuted),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      l10n.employeeResetPasswordConfirm(
                          widget.manager.fullName),
                      style: typography.caption
                          .copyWith(color: AppColors.colorTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.dialogCancel,
          variant: AppButtonVariant.outline,
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSpacing.space8),
        AppButton(
          label: l10n.employeeResetPasswordSetAction,
          variant: AppButtonVariant.primary,
          isLoading: _isLoading,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              _handleSubmit();
            }
          },
        ),
      ],
    );
  }
}
