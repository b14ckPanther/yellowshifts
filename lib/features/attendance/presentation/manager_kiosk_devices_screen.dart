import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'providers/kiosk_providers.dart';
import 'widgets/kiosk_health_badge.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';

class ManagerKioskDevicesScreen extends ConsumerWidget {
  const ManagerKioskDevicesScreen({super.key});

  void _showProvisionDialog(BuildContext context, WidgetRef ref,
      String stationId, AppLocalizations l10n) {
    final nameController = TextEditingController();
    final identController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.kioskProvisionNewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.kioskDeviceNameLabel),
            ),
            const SizedBox(height: AppSpacing.space12),
            TextField(
              controller: identController,
              decoration:
                  InputDecoration(labelText: l10n.kioskDeviceIdentifierLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.dialogCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty &&
                  identController.text.trim().isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                final repo = ref.read(kioskRepositoryProvider);
                final res = await repo.provisionKioskDevice(
                  stationId: stationId,
                  name: nameController.text.trim(),
                  deviceIdentifier: identController.text.trim(),
                );
                ref.invalidate(stationKioskDevicesProvider(stationId));

                if (context.mounted) {
                  _showSecretModal(context, res['raw_secret'] as String,
                      res['device_identifier'] as String, l10n);
                }
              }
            },
            child: Text(l10n.kioskProvisionAction),
          ),
        ],
      ),
    );
  }

  void _showSecretModal(BuildContext context, String rawSecret,
      String identifier, AppLocalizations l10n) {
    const typography = AppTypography();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: AppColors.colorWarning),
            const SizedBox(width: AppSpacing.space8),
            Text(l10n.kioskSecretTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.kioskSecretWarning,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(l10n.kioskDeviceLabel(identifier),
                style: typography.bodyStrong),
            const SizedBox(height: AppSpacing.space8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                rawSecret,
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(l10n.kioskCopySecretAction),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawSecret));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.kioskSecretCopiedToast)),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.kioskDoneAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final stationId = ref.watch(activeStationIdProvider);

    if (stationId == null) {
      return Scaffold(body: Center(child: Text(l10n.stationSelectTitle)));
    }

    final kiosksAsync = ref.watch(stationKioskDevicesProvider(stationId));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        title: Text(l10n.kioskDevicesTitle),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: AppColors.colorTextPrimary,
            ),
            icon: const Icon(LucideIcons.qrCode, size: 16),
            label: Text(l10n.kioskLaunchModeButton),
            onPressed: () => context.push('/kiosk'),
          ),
          const SizedBox(width: AppSpacing.space8),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () =>
                _showProvisionDialog(context, ref, stationId, l10n),
          ),
        ],
      ),
      body: kiosksAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.tablet,
                        size: 48, color: AppColors.colorSurfaceBrand),
                    const SizedBox(height: AppSpacing.space16),
                    Text(
                      l10n.kioskEmptyTitle,
                      style: typography.titleLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      l10n.kioskEmptyDesc,
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showProvisionDialog(context, ref, stationId, l10n),
                      icon: const Icon(LucideIcons.plus),
                      label: Text(l10n.kioskProvisionNewTitle),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.space16),
            itemCount: devices.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.space12),
            itemBuilder: (context, idx) {
              final d = devices[idx];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.space16),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.colorBorderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.colorTextPrimary,
                                ),
                              ),
                              Text(
                                'ID: ${d.deviceIdentifier} • v${d.credentialVersion}',
                                style: typography.caption.copyWith(
                                  color: AppColors.colorTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        KioskHealthBadge(device: d),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Text(
                      d.lastSeenAt != null
                          ? l10n.kioskLastSeen(
                              dateFormat.format(d.lastSeenAt!.toLocal()))
                          : l10n.kioskNeverConnected,
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(LucideIcons.keyRound, size: 16),
                          label: Text(l10n.kioskRotateSecretAction),
                          onPressed: () async {
                            try {
                              final repo = ref.read(kioskRepositoryProvider);
                              final res =
                                  await repo.rotateKioskCredentials(d.id);
                              ref.invalidate(
                                  stationKioskDevicesProvider(stationId));
                              if (context.mounted) {
                                _showSecretModal(
                                    context,
                                    res['raw_secret'] as String,
                                    d.deviceIdentifier,
                                    l10n);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(ErrorLocalizer.localize(e, l10n)),
                                    backgroundColor: AppColors.colorError,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        TextButton.icon(
                          icon: Icon(
                            d.isActive
                                ? LucideIcons.powerOff
                                : LucideIcons.power,
                            size: 16,
                            color: d.isActive
                                ? AppColors.colorError
                                : AppColors.colorSuccess,
                          ),
                          label: Text(
                            d.isActive
                                ? l10n.kioskDeactivateAction
                                : l10n.kioskReactivateAction,
                            style: TextStyle(
                                color: d.isActive
                                    ? AppColors.colorError
                                    : AppColors.colorSuccess),
                          ),
                          onPressed: () async {
                            try {
                              final repo = ref.read(kioskRepositoryProvider);
                              if (d.isActive) {
                                await repo.deactivateKioskDevice(d.id);
                              } else {
                                await repo.reactivateKioskDevice(d.id);
                              }
                              ref.invalidate(
                                  stationKioskDevicesProvider(stationId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(d.isActive
                                        ? l10n.kioskDeactivatedToast
                                        : l10n.kioskReactivatedToast),
                                    backgroundColor: AppColors.colorSuccess,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(ErrorLocalizer.localize(e, l10n)),
                                    backgroundColor: AppColors.colorError,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(ErrorLocalizer.localize(err, l10n))),
      ),
    );
  }
}
