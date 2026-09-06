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
import '../../domain/platform_station_summary.dart';
import '../platform_admin_providers.dart';

class EditStationDialog extends ConsumerStatefulWidget {
  final PlatformStationSummary station;

  const EditStationDialog({super.key, required this.station});

  static Future<bool?> show(
    BuildContext context, {
    required PlatformStationSummary station,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EditStationDialog(station: station),
    );
  }

  @override
  ConsumerState<EditStationDialog> createState() => _EditStationDialogState();
}

class _EditStationDialogState extends ConsumerState<EditStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  final String _timezone = 'Asia/Jerusalem';
  String _locale = 'he';
  int _weekStart = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.station.name);
    _codeController = TextEditingController(text: widget.station.code);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      await ref.read(platformAdminRepositoryProvider).updateStation(
            stationId: widget.station.id,
            name: _nameController.text.trim(),
            code: _codeController.text.trim().toUpperCase(),
            timezone: _timezone,
            locale: _locale,
            weekStart: _weekStart,
          );

      ref.invalidate(platformStationsProvider);
      ref.invalidate(platformOverviewProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppFeedback.show(
          context,
          message: l10n.platformStationUpdatedToast,
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
      title: l10n.platformEditStation,
      subtitle: l10n.platformEditStationSubtitle,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              label: l10n.platformStationName,
              prefixIcon: LucideIcons.building2,
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Station name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              controller: _codeController,
              label: l10n.platformStationCode,
              prefixIcon: LucideIcons.hash,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Station code is required';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space12),
            DropdownButtonFormField<String>(
              initialValue: _locale,
              decoration: InputDecoration(
                labelText: l10n.platformStationLocale,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(LucideIcons.globe, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'he', child: Text('עברית (Hebrew)')),
                DropdownMenuItem(value: 'en', child: Text('English (US)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _locale = v);
              },
            ),
            const SizedBox(height: AppSpacing.space12),
            DropdownButtonFormField<int>(
              initialValue: _weekStart,
              decoration: InputDecoration(
                labelText: l10n.platformWeekStart,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space8,
                ),
              ),
              items: [
                DropdownMenuItem(
                    value: 0, child: Text(l10n.platformWeekStartSunday)),
                DropdownMenuItem(
                    value: 1, child: Text(l10n.platformWeekStartMonday)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _weekStart = v);
              },
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
