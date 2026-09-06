import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_dialog.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/platform_admin_repository.dart';
import '../../domain/platform_station_manager.dart';
import '../platform_admin_providers.dart';

class EditPlatformManagerDialog extends ConsumerStatefulWidget {
  final String stationId;
  final PlatformStationManager manager;

  const EditPlatformManagerDialog({
    super.key,
    required this.stationId,
    required this.manager,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String stationId,
    required PlatformStationManager manager,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EditPlatformManagerDialog(
        stationId: stationId,
        manager: manager,
      ),
    );
  }

  @override
  ConsumerState<EditPlatformManagerDialog> createState() =>
      _EditPlatformManagerDialogState();
}

class _EditPlatformManagerDialogState
    extends ConsumerState<EditPlatformManagerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstController;
  late final TextEditingController _lastController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstController = TextEditingController(text: widget.manager.firstName);
    _lastController = TextEditingController(text: widget.manager.lastName);
    _emailController = TextEditingController(text: widget.manager.email ?? '');
    _phoneController = TextEditingController(text: widget.manager.phone ?? '');
    _codeController =
        TextEditingController(text: widget.manager.employeeCode ?? '');
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      await ref.read(platformAdminRepositoryProvider).updateStationManager(
            stationId: widget.stationId,
            userId: widget.manager.userId,
            firstName: _firstController.text.trim(),
            lastName: _lastController.text.trim(),
            email: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            employeeCode: _codeController.text.trim().isNotEmpty
                ? _codeController.text.trim()
                : null,
          );

      ref.invalidate(platformStationManagersProvider(widget.stationId));
      ref.invalidate(platformStationsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppFeedback.show(
          context,
          message: l10n.platformManagerUpdatedToast,
          type: AppFeedbackType.success,
        );
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

    return AppDialog(
      title: l10n.platformEditManager,
      subtitle: l10n.platformEditManagerSubtitle(widget.manager.fullName),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _firstController,
                    label: l10n.platformManagerFirstName,
                    prefixIcon: LucideIcons.user,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: AppTextField(
                    controller: _lastController,
                    label: l10n.platformManagerLastName,
                    prefixIcon: LucideIcons.user,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              controller: _emailController,
              label: l10n.platformManagerEmail,
              prefixIcon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(
                      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Invalid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              controller: _phoneController,
              label: l10n.platformManagerPhone,
              prefixIcon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              controller: _codeController,
              label: l10n.createEmployeeCode,
              prefixIcon: LucideIcons.badgeCheck,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.dialogCancel,
          variant: AppButtonVariant.outline,
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: AppSpacing.space8),
        AppButton(
          label: l10n.commonSave,
          variant: AppButtonVariant.primary,
          isLoading: _isLoading,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
