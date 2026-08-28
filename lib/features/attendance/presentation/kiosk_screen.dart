import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'providers/kiosk_providers.dart';
import 'widgets/dynamic_qr_display.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';

class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _showSetupDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final identController = TextEditingController();
    final secretController = TextEditingController();
    final activeMembership = ref.read(activeMembershipProvider);
    bool isSubmitting = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.kioskSetupDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space8),
                  decoration: BoxDecoration(
                    color: AppColors.colorError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.colorError),
                  ),
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                        color: AppColors.colorError, fontSize: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
              ],
              TextField(
                controller: identController,
                decoration: InputDecoration(
                  labelText: l10n.kioskDeviceIdentifierLabel,
                  hintText: l10n.kioskDeviceIdentifierHint,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              TextField(
                controller: secretController,
                decoration: InputDecoration(
                  labelText: l10n.kioskDeviceSecretLabel,
                  hintText: l10n.kioskDeviceSecretHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.dialogCancel),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final ident = identController.text.trim();
                      final sec = secretController.text.trim();
                      if (ident.isEmpty || sec.isEmpty) {
                        setDialogState(() {
                          errorText = l10n.kioskValidationRequired;
                        });
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        final stationId = activeMembership?.stationId ?? '';
                        await ref
                            .read(kioskSessionProvider.notifier)
                            .startSession(
                              stationId: stationId,
                              deviceIdentifier: ident,
                              deviceSecret: sec,
                            );
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = l10n.kioskConnectionFailed(
                              e.toString().replaceAll('Exception: ', ''));
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.kioskConnectAction),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();
    final session = ref.watch(kioskSessionProvider);
    final localeName = Localizations.localeOf(context).toString();
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', localeName);

    if (session == null || session.currentChallenge == null) {
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.tablet,
                    size: 64, color: AppColors.colorSurfaceBrand),
                const SizedBox(height: AppSpacing.space24),
                Text(
                  l10n.kioskScreenTitle,
                  style: typography.displayLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  l10n.kioskScreenUnconfiguredDesc,
                  textAlign: TextAlign.center,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.colorTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space32),
                ElevatedButton.icon(
                  onPressed: () => _showSetupDialog(context),
                  icon: const Icon(LucideIcons.settings),
                  label: Text(l10n.kioskConfigureDeviceAction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorSurfaceBrand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space24,
                        vertical: AppSpacing.space16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final challenge = session.currentChallenge!;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Column(
            children: [
              // Top Bar: Station Name & Live Clock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        decoration: BoxDecoration(
                          color: AppColors.colorSurfaceBrand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.fuel,
                            color: Colors.black, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.stationName.isNotEmpty
                                ? challenge.stationName
                                : l10n.kioskDefaultTitle,
                            style: typography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.colorTextPrimary,
                            ),
                          ),
                          Text(
                            dateFormat.format(_currentTime),
                            style: typography.caption.copyWith(
                              color: AppColors.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    timeFormat.format(_currentTime),
                    style: typography.displayLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.colorActionPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Center: Dynamic QR & Manual Code
              DynamicQrDisplay(
                challenge: challenge,
                onRefresh: () => ref
                    .read(kioskSessionProvider.notifier)
                    .refreshQrChallenge(),
              ),
              const SizedBox(height: AppSpacing.space24),
              Text(
                l10n.kioskScanInstruction,
                textAlign: TextAlign.center,
                style: typography.titleMedium.copyWith(
                  color: AppColors.colorTextSecondary,
                ),
              ),
              const Spacer(),
              // Bottom status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.colorSuccess,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Text(
                    l10n.kioskConnectedStatus(session.deviceIdentifier),
                    style: typography.caption.copyWith(
                      color: AppColors.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
