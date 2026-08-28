import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
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
                    DropdownButtonFormField<String>(
                      key: ValueKey(_locale),
                      initialValue: _locale,
                      decoration: InputDecoration(
                          labelText: l10n.platformStationLocale),
                      items: const [
                        DropdownMenuItem(value: 'he', child: Text('עברית')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v != null) setState(() => _locale = v);
                            },
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    DropdownButtonFormField<int>(
                      key: ValueKey(_weekStart),
                      initialValue: _weekStart,
                      decoration:
                          InputDecoration(labelText: l10n.platformWeekStart),
                      items: [
                        DropdownMenuItem(
                            value: 0,
                            child: Text(l10n.platformWeekStartSunday)),
                        DropdownMenuItem(
                            value: 1,
                            child: Text(l10n.platformWeekStartMonday)),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v != null) setState(() => _weekStart = v);
                            },
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    Text(l10n.platformInitialManager),
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
}
