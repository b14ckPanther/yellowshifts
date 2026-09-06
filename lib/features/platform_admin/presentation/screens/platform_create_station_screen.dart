import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/platform_admin_repository.dart';
import '../platform_admin_providers.dart';

class PlatformCreateStationScreen extends ConsumerStatefulWidget {
  const PlatformCreateStationScreen({super.key});

  @override
  ConsumerState<PlatformCreateStationScreen> createState() =>
      _PlatformCreateStationScreenState();
}

class _PlatformCreateStationScreenState
    extends ConsumerState<PlatformCreateStationScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _timezone = TextEditingController(text: 'Asia/Jerusalem');
  String _locale = 'he';
  int _weekStart = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_name.text.trim().length < 2 || _code.text.trim().length < 2) {
      setState(() => _error = l10n.errorInvalidInput);
      return;
    }
    if (_email.text.trim().isNotEmpty &&
        (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty)) {
      setState(() => _error = l10n.errorInvalidInput);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final idempotency =
          'create-${_code.text.trim().toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(platformAdminRepositoryProvider).createStation(
            name: _name.text.trim(),
            code: _code.text.trim(),
            timezone: _timezone.text.trim().isEmpty
                ? 'Asia/Jerusalem'
                : _timezone.text.trim(),
            locale: _locale,
            weekStart: _weekStart,
            idempotencyKey: idempotency,
            initialAdminEmail:
                _email.text.trim().isEmpty ? null : _email.text.trim(),
            initialAdminFirstName:
                _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
            initialAdminLastName:
                _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
            initialAdminPhone:
                _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      ref.invalidate(platformStationsProvider);
      ref.invalidate(platformOverviewProvider);
      if (mounted) {
        AppFeedback.show(context,
            message: l10n.platformCreatedToast, type: AppFeedbackType.success);
        context.go('/platform/stations');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = ErrorLocalizer.localize(e, l10n));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: ListView(
          children: [
            AppPageHeader(
              title: l10n.platformCreateStationTitle,
              subtitle: l10n.platformCreateStationSubtitle,
              onBack: () => context.go('/platform/stations'),
            ),
            Padding(
              padding: AppSpacing.insetHorizontal16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.colorStatusDanger)),
                      const SizedBox(height: AppSpacing.space12),
                    ],
                    AppTextField(
                        label: l10n.platformStationName, controller: _name),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                        label: l10n.platformStationCode, controller: _code),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                      label: l10n.platformStationTimezone,
                      controller: _timezone,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      children: [
                        Expanded(
                          child: _customDropdownField<String>(
                            label: l10n.platformStationLocale,
                            value: _locale,
                            items: const [
                              DropdownMenuItem(value: 'he', child: Text('עברית (Hebrew)')),
                              DropdownMenuItem(value: 'en', child: Text('English (US)')),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) {
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
                            onChanged: _saving
                                ? null
                                : (v) {
                                    if (v != null) setState(() => _weekStart = v);
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    Text(
                      l10n.platformInitialManager,
                      style: const AppTypography().bodyStrong.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.colorTextPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                        label: l10n.platformManagerEmail, controller: _email),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                        label: l10n.platformManagerFirstName,
                        controller: _firstName),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                        label: l10n.platformManagerLastName,
                        controller: _lastName),
                    const SizedBox(height: AppSpacing.space12),
                    AppTextField(
                        label: l10n.platformManagerPhone, controller: _phone),
                    const SizedBox(height: AppSpacing.space24),
                    AppButton(
                      label: l10n.platformCreateStation,
                      isLoading: _saving,
                      onPressed: _saving ? null : _submit,
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

  Widget _customDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
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
