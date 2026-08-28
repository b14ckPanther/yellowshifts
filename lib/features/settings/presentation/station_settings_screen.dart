import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_feedback.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';
import 'station_settings_controller.dart';

class StationSettingsScreen extends ConsumerStatefulWidget {
  const StationSettingsScreen({super.key});

  @override
  ConsumerState<StationSettingsScreen> createState() =>
      _StationSettingsScreenState();
}

class _StationSettingsScreenState extends ConsumerState<StationSettingsScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _lateGraceController = TextEditingController(text: '5');
  final _earlyCheckInController = TextEditingController(text: '15');
  String _selectedTimezone = 'Asia/Jerusalem';
  String _selectedLocale = 'he';
  int _selectedWeekStart = 0; // 0 = Sunday
  bool _isActive = true;
  bool _initialized = false;

  final List<String> _validTimezones = const [
    'Asia/Jerusalem',
    'UTC',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _lateGraceController.dispose();
    _earlyCheckInController.dispose();
    super.dispose();
  }

  void _initFields() {
    if (_initialized) return;
    final activeMembership = ref.read(activeMembershipProvider);
    final station = activeMembership?.station;
    if (station != null) {
      _nameController.text = station.name;
      _codeController.text = station.code;
      _lateGraceController.text = station.lateGraceMinutes.toString();
      _earlyCheckInController.text = station.checkInEarlyMinutes.toString();
      _selectedTimezone = _validTimezones.contains(station.timezone)
          ? station.timezone
          : 'Asia/Jerusalem';
      _selectedLocale = station.locale;
      _selectedWeekStart = station.weekStart;
      _isActive = station.isActive;
      _initialized = true;
    }
  }

  Future<void> _handleSave(
      {bool forceDeactivate = false, String? deactivationReason}) async {
    final activeMembership = ref.read(activeMembershipProvider);
    final stationId = activeMembership?.stationId;
    if (stationId == null) return;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    final lateGrace = int.tryParse(_lateGraceController.text.trim()) ?? 5;
    final earlyCheckIn =
        int.tryParse(_earlyCheckInController.text.trim()) ?? 15;

    if (name.isEmpty || code.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Station Name and Station Code are required.',
        type: AppFeedbackType.error,
      );
      return;
    }

    try {
      await ref.read(stationSettingsControllerProvider.notifier).saveSettings(
            stationId: stationId,
            name: name,
            code: code,
            timezone: _selectedTimezone,
            locale: _selectedLocale,
            weekStart: _selectedWeekStart,
            isActive: _isActive,
            lateGraceMinutes: lateGrace,
            checkInEarlyMinutes: earlyCheckIn,
            forceDeactivate: forceDeactivate,
            deactivationReason: deactivationReason,
          );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppFeedback.show(context, message: l10n.stationSettingsSaved);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final errorMsg = ErrorLocalizer.localize(e, l10n);

        if (e.toString().contains('P0082') ||
            errorMsg == l10n.errorActiveAttendanceBlocksDeactivation) {
          _showForceDeactivateDialog(context, l10n);
        } else {
          AppFeedback.show(
            context,
            message: errorMsg,
            type: AppFeedbackType.error,
          );
        }
      }
    }
  }

  Future<void> _showForceDeactivateDialog(
      BuildContext context, AppLocalizations l10n) async {
    const typography = AppTypography();
    final reasonController = TextEditingController(
        text: 'Administrative operational maintenance shutdown');
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.stationDangerZone,
            style: typography.titleMedium
                .copyWith(color: AppColors.colorStatusDanger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.stationDeactivateBlockedActive}\n\nPlease enter an explicit mandatory reason for the audit log:',
              style: typography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.space12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Force Deactivation (min 10 chars)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.dialogCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.colorStatusDanger),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.length >= 10) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: Text(l10n.stationForceDeactivateConfirm),
          ),
        ],
      ),
    );

    if (reason != null && reason.length >= 10) {
      await _handleSave(forceDeactivate: true, deactivationReason: reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final activeMembership = ref.watch(activeMembershipProvider);
    final state = ref.watch(stationSettingsControllerProvider);

    _initFields();

    final isAdmin = activeMembership?.role.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.stationSettingsTitle,
                subtitle: l10n.stationSettingsSubtitle,
                onBack: () => context.go('/settings'),
                actions: [
                  if (isAdmin)
                    AppButton(
                      label: l10n.commonSave,
                      icon: LucideIcons.save,
                      isLoading: state.isLoading,
                      onPressed: () => _handleSave(),
                    ),
                ],
              ),
              Padding(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  children: [
                    // Section 1: Operational Identity
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.stationSectionIdentity,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          AppTextField(
                            label: l10n.stationSettingsName,
                            controller: _nameController,
                            readOnly: !isAdmin,
                            prefixIcon: const Icon(LucideIcons.building2,
                                size: 16.0, color: AppColors.colorTextMuted),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          AppTextField(
                            label: l10n.stationSettingsCode,
                            controller: _codeController,
                            readOnly: !isAdmin,
                            prefixIcon: const Icon(LucideIcons.badge,
                                size: 16.0, color: AppColors.colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Section 2: Regional, Timezone & Calendar Defaults
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.stationSectionRegional,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          Text(l10n.stationTimezoneLabel,
                              style: typography.bodyStrong),
                          const SizedBox(height: 4),
                          Text(l10n.stationTimezoneHelper,
                              style: typography.bodySmall
                                  .copyWith(color: AppColors.colorTextMuted)),
                          const SizedBox(height: AppSpacing.space8),
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
                              child: DropdownButton<String>(
                                value: _selectedTimezone,
                                isExpanded: true,
                                items: _validTimezones
                                    .map((tz) => DropdownMenuItem(
                                        value: tz,
                                        child: Text(tz,
                                            style: typography.bodyMedium)))
                                    .toList(),
                                onChanged: isAdmin
                                    ? (val) => setState(() =>
                                        _selectedTimezone =
                                            val ?? _selectedTimezone)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          Text(l10n.stationSettingsLocale,
                              style: typography.bodyStrong),
                          const SizedBox(height: AppSpacing.space8),
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
                              child: DropdownButton<String>(
                                value: _selectedLocale,
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                      value: 'he',
                                      child: Text('עברית (Hebrew - RTL)',
                                          style: typography.bodyMedium)),
                                  DropdownMenuItem(
                                      value: 'en',
                                      child: Text('English (LTR)',
                                          style: typography.bodyMedium)),
                                ],
                                onChanged: isAdmin
                                    ? (val) => setState(() => _selectedLocale =
                                        val ?? _selectedLocale)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          Text(l10n.stationSettingsWeekStart,
                              style: typography.bodyStrong),
                          const SizedBox(height: AppSpacing.space8),
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
                              child: DropdownButton<int>(
                                value: _selectedWeekStart,
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                      value: 0,
                                      child: Text(l10n.stationSettingsSunday,
                                          style: typography.bodyMedium)),
                                  DropdownMenuItem(
                                      value: 1,
                                      child: Text(l10n.stationSettingsMonday,
                                          style: typography.bodyMedium)),
                                ],
                                onChanged: isAdmin
                                    ? (val) => setState(() =>
                                        _selectedWeekStart =
                                            val ?? _selectedWeekStart)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Section 3: Phase 8 Operational Grace Windows
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.stationSectionGrace,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          AppTextField(
                            label: l10n.stationLateGraceMinutes,
                            helperText: l10n.stationLateGraceHelper,
                            controller: _lateGraceController,
                            keyboardType: TextInputType.number,
                            readOnly: !isAdmin,
                            prefixIcon: const Icon(LucideIcons.clockAlert,
                                size: 16.0, color: AppColors.colorTextMuted),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          AppTextField(
                            label: l10n.stationCheckInEarlyMinutes,
                            helperText: l10n.stationCheckInEarlyHelper,
                            controller: _earlyCheckInController,
                            keyboardType: TextInputType.number,
                            readOnly: !isAdmin,
                            prefixIcon: const Icon(LucideIcons.alarmClock,
                                size: 16.0, color: AppColors.colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Section 4: Sensitive Station Controls / Danger Zone
                    if (isAdmin)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.alertOctagon,
                                    color: AppColors.colorStatusDanger,
                                    size: 20),
                                const SizedBox(width: AppSpacing.space8),
                                Expanded(
                                  child: Text(
                                    l10n.stationDangerZone,
                                    style: typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.colorStatusDanger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.space8),
                            Text(
                              l10n.stationDeactivateNotice,
                              style: typography.bodySmall
                                  .copyWith(color: AppColors.colorTextMuted),
                            ),
                            const SizedBox(height: AppSpacing.space16),
                            Container(
                              padding: AppSpacing.insetAll12,
                              decoration: BoxDecoration(
                                color: _isActive
                                    ? AppColors.colorSurfaceBase
                                    : AppColors.colorStatusDangerSubtle,
                                borderRadius: AppRadius.borderMd,
                                border: Border.all(
                                  color: _isActive
                                      ? AppColors.colorBorderSubtle
                                      : AppColors.colorStatusDanger
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isActive
                                              ? l10n.stationActiveStatus
                                              : l10n.stationDeactivatedStatus,
                                          style: typography.bodyStrong.copyWith(
                                            color: _isActive
                                                ? AppColors.colorTextPrimary
                                                : AppColors.colorStatusDanger,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: AppSpacing.space4),
                                        Text(
                                          _isActive
                                              ? l10n.stationActiveDesc
                                              : l10n.stationDeactivatedDesc,
                                          style: typography.bodySmall.copyWith(
                                            color: AppColors.colorTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space12),
                                  Switch(
                                    value: _isActive,
                                    activeThumbColor:
                                        AppColors.colorTextInverse,
                                    activeTrackColor:
                                        AppColors.colorActionPrimary,
                                    onChanged: (val) {
                                      setState(() => _isActive = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
