import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../permissions/presentation/shift_manager_permissions_provider.dart';

class ShiftManagerPermissionsScreen extends ConsumerStatefulWidget {
  const ShiftManagerPermissionsScreen({super.key});

  @override
  ConsumerState<ShiftManagerPermissionsScreen> createState() =>
      _ShiftManagerPermissionsScreenState();
}

class _ShiftManagerPermissionsScreenState
    extends ConsumerState<ShiftManagerPermissionsScreen> {
  bool _shiftTemplatesManage = false;
  bool _availabilityPeriodCreate = false;
  bool _availabilityPeriodOpen = false;
  bool _availabilityPeriodClose = false;
  bool _availabilityTeamRead = true;
  bool _isSaving = false;
  bool _isInitialized = false;

  void _syncInitial(dynamic perms) {
    if (!_isInitialized && perms != null) {
      _shiftTemplatesManage = perms.shiftTemplatesManage;
      _availabilityPeriodCreate = perms.availabilityPeriodCreate;
      _availabilityPeriodOpen = perms.availabilityPeriodOpen;
      _availabilityPeriodClose = perms.availabilityPeriodClose;
      _availabilityTeamRead = perms.availabilityTeamRead;
      _isInitialized = true;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(shiftManagerPermissionsProvider).value;
    if (current == null) return;

    final updated = current.copyWith(
      shiftTemplatesManage: _shiftTemplatesManage,
      availabilityPeriodCreate: _availabilityPeriodCreate,
      availabilityPeriodOpen: _availabilityPeriodOpen,
      availabilityPeriodClose: _availabilityPeriodClose,
      availabilityTeamRead: _availabilityTeamRead,
    );

    try {
      await ref
          .read(shiftManagerPermissionsProvider.notifier)
          .updatePermissions(updated);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.permissionsSavedToast)),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save permissions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final permsAsync = ref.watch(shiftManagerPermissionsProvider);

    permsAsync.whenData((perms) => _syncInitial(perms));

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: l10n.permissionsTitle,
              subtitle: l10n.permissionsSubtitle,
              actions: [
                AppButton(
                  label: l10n.permissionsSaveButton,
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shift Templates Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.permissionsSectionTemplates,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          _buildSwitchRow(
                            title: l10n.permissionsShiftTemplatesManage,
                            subtitle:
                                'Allows shift managers to add, modify, and reorder station templates',
                            value: _shiftTemplatesManage,
                            onChanged: (val) =>
                                setState(() => _shiftTemplatesManage = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Weekly Availability Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.permissionsSectionAvailability,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          _buildSwitchRow(
                            title: l10n.permissionsAvailabilityTeamRead,
                            subtitle:
                                'Allows shift managers to view team matrix and submission progress',
                            value: _availabilityTeamRead,
                            onChanged: (val) =>
                                setState(() => _availabilityTeamRead = val),
                          ),
                          const Divider(color: AppColors.colorBorderSubtle),
                          _buildSwitchRow(
                            title: l10n.permissionsAvailabilityPeriodCreate,
                            subtitle:
                                'Allows creating new draft availability weeks',
                            value: _availabilityPeriodCreate,
                            onChanged: (val) =>
                                setState(() => _availabilityPeriodCreate = val),
                          ),
                          const Divider(color: AppColors.colorBorderSubtle),
                          _buildSwitchRow(
                            title: l10n.permissionsAvailabilityPeriodOpen,
                            subtitle:
                                'Allows opening submissions and freezing template snapshots',
                            value: _availabilityPeriodOpen,
                            onChanged: (val) =>
                                setState(() => _availabilityPeriodOpen = val),
                          ),
                          const Divider(color: AppColors.colorBorderSubtle),
                          _buildSwitchRow(
                            title: l10n.permissionsAvailabilityPeriodClose,
                            subtitle:
                                'Allows closing submission periods and reopening with new deadlines',
                            value: _availabilityPeriodClose,
                            onChanged: (val) =>
                                setState(() => _availabilityPeriodClose = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const typography = AppTypography();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: typography.bodyStrong),
                const SizedBox(height: AppSpacing.space2),
                Text(subtitle,
                    style: typography.caption
                        .copyWith(color: AppColors.colorTextSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space16),
          Switch(
            value: value,
            activeThumbColor: AppColors.colorBrandYellow,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
