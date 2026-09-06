import 'package:flutter/material.dart';
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
import '../../domain/platform_station_summary.dart';
import '../platform_admin_providers.dart';
import 'reset_manager_password_dialog.dart';

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

  // Station Fields
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  final String _timezone = 'Asia/Jerusalem';
  String _locale = 'he';
  int _weekStart = 0;

  // Manager Fields
  final _managerFirstController = TextEditingController();
  final _managerLastController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerCodeController = TextEditingController();

  PlatformStationManager? _primaryManager;
  bool _hasLoadedManager = false;
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
    _managerFirstController.dispose();
    _managerLastController.dispose();
    _managerEmailController.dispose();
    _managerPhoneController.dispose();
    _managerCodeController.dispose();
    super.dispose();
  }

  void _populateManagerIfAvailable(List<PlatformStationManager> managers) {
    if (_hasLoadedManager) return;
    if (managers.isNotEmpty) {
      _primaryManager = managers.first;
      _managerFirstController.text = _primaryManager!.firstName;
      _managerLastController.text = _primaryManager!.lastName;
      _managerEmailController.text = _primaryManager!.email ?? '';
      _managerPhoneController.text = _primaryManager!.phone ?? '';
      _managerCodeController.text = _primaryManager!.employeeCode ?? '';
    }
    _hasLoadedManager = true;
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(platformAdminRepositoryProvider);

      // 1. Update Station parameters
      await repo.updateStation(
        stationId: widget.station.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        timezone: _timezone,
        locale: _locale,
        weekStart: _weekStart,
      );

      // 2. Update or Assign Station Manager if fields are provided
      final mFirst = _managerFirstController.text.trim();
      final mLast = _managerLastController.text.trim();
      final mEmail = _managerEmailController.text.trim();
      final mPhone = _managerPhoneController.text.trim();
      final mCode = _managerCodeController.text.trim();

      if (mFirst.isNotEmpty && mLast.isNotEmpty) {
        if (_primaryManager != null) {
          // Update existing manager
          await repo.updateStationManager(
            stationId: widget.station.id,
            userId: _primaryManager!.userId,
            firstName: mFirst,
            lastName: mLast,
            email: mEmail.isNotEmpty ? mEmail : null,
            phone: mPhone.isNotEmpty ? mPhone : null,
            employeeCode: mCode.isNotEmpty ? mCode : null,
          );
        } else if (mEmail.isNotEmpty) {
          // Assign initial/new manager
          await repo.assignStationAdmin(
            stationId: widget.station.id,
            firstName: mFirst,
            lastName: mLast,
            email: mEmail,
            phone: mPhone.isNotEmpty ? mPhone : null,
          );
        }
      }

      ref.invalidate(platformStationsProvider);
      ref.invalidate(platformOverviewProvider);
      ref.invalidate(platformStationManagersProvider(widget.station.id));

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
    const typography = AppTypography();

    // Watch managers to pre-fill manager fields
    final managersAsync =
        ref.watch(platformStationManagersProvider(widget.station.id));
    managersAsync.whenData((managers) => _populateManagerIfAvailable(managers));

    return AppDialog(
      title: l10n.platformEditStation,
      subtitle: l10n.platformEditStationSubtitle,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          maxWidth: 540,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECTION 1: STATION DETAILS
                _sectionHeader(l10n.platformStationName, LucideIcons.building2, typography),
                const SizedBox(height: AppSpacing.space8),
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
                Row(
                  children: [
                    Expanded(
                      child: _customDropdownField(
                        label: l10n.platformStationLocale,
                        value: _locale,
                        items: const [
                          DropdownMenuItem(value: 'he', child: Text('עברית (Hebrew)')),
                          DropdownMenuItem(value: 'en', child: Text('English (US)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _locale = v);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: _customDropdownField<int>(
                        label: l10n.platformWeekStart,
                        value: _weekStart,
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
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.space24),
                const Divider(height: 1, color: AppColors.colorBorderSubtle),
                const SizedBox(height: AppSpacing.space16),

                // SECTION 2: STATION MANAGER (ADMIN)
                Row(
                  children: [
                    Expanded(
                      child: _sectionHeader(
                        l10n.platformInitialManager,
                        LucideIcons.shieldCheck,
                        typography,
                      ),
                    ),
                    if (_primaryManager != null) ...[
                      TextButton.icon(
                        icon: const Icon(LucideIcons.keyRound, size: 14),
                        label: Text(
                          l10n.platformResetManagerPassword,
                          style: typography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.colorActionPrimary,
                          ),
                        ),
                        onPressed: () {
                          ResetManagerPasswordDialog.show(
                            context,
                            stationId: widget.station.id,
                            manager: _primaryManager!,
                          );
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _managerFirstController,
                        label: l10n.platformManagerFirstName,
                        prefixIcon: LucideIcons.user,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: AppTextField(
                        controller: _managerLastController,
                        label: l10n.platformManagerLastName,
                        prefixIcon: LucideIcons.user,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                AppTextField(
                  controller: _managerEmailController,
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
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _managerPhoneController,
                        label: l10n.platformManagerPhone,
                        prefixIcon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: AppTextField(
                        controller: _managerCodeController,
                        label: l10n.createEmployeeCode,
                        prefixIcon: LucideIcons.badgeCheck,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _sectionHeader(String title, IconData icon, AppTypography typography) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.colorTextBrand),
        const SizedBox(width: 6),
        Text(
          title,
          style: typography.bodyStrong.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.colorTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _customDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    const typography = AppTypography();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: typography.caption.copyWith(
            color: AppColors.colorTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
          decoration: BoxDecoration(
            color: AppColors.colorSurfaceRaised,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.colorBorderSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: typography.bodyLarge.copyWith(color: AppColors.colorTextPrimary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
