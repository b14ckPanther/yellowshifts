import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../domain/models/station_nfc_tag.dart';
import 'providers/nfc_providers.dart';
import 'widgets/nfc_provision_dialog.dart';

class ManagerNfcTagsScreen extends ConsumerWidget {
  const ManagerNfcTagsScreen({super.key});

  String _buildFullNfcUrl(String token) {
    if (kIsWeb) {
      final base = Uri.base;
      final portStr = (base.hasPort && base.port != 80 && base.port != 443)
          ? ':${base.port}'
          : '';
      final origin = '${base.scheme}://${base.host}$portStr';
      return '$origin/nfc/t/$token';
    }
    return 'https://app.yellowshifts.com/nfc/t/$token';
  }

  void _showProvisionDialog(
      BuildContext context, WidgetRef ref, String stationId) {
    showDialog(
      context: context,
      builder: (_) => NfcProvisionDialog(stationId: stationId),
    );
  }

  void _showRegenerateDialog(BuildContext context, WidgetRef ref,
      StationNfcTag tag, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.colorSurfaceRaised,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(LucideIcons.refreshCw, color: AppColors.colorWarning),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                l10n.nfcRegenerateTokenTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nfcRegenerateTokenDesc,
              style: const TextStyle(color: AppColors.colorTextSecondary),
            ),
            const SizedBox(height: AppSpacing.space12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space10),
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBase,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: Text(
                tag.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
              Navigator.of(dialogCtx).pop();
              try {
                final repo = ref.read(nfcTagRepositoryProvider);
                final res = await repo.regenerateStationNfcTag(tag.id);
                ref.invalidate(stationNfcTagsProvider(tag.stationId));

                final token = res['token'] as String? ?? '';
                final fullUrl = _buildFullNfcUrl(token);

                if (context.mounted) {
                  _showRegeneratedUrlDialog(context, tag.name, fullUrl, l10n);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ErrorLocalizer.localize(e, l10n)),
                      backgroundColor: AppColors.colorError,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorWarning,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.nfcRegenerateConfirm),
          ),
        ],
      ),
    );
  }

  void _showRegeneratedUrlDialog(BuildContext context, String tagName,
      String fullUrl, AppLocalizations l10n) {
    const typography = AppTypography();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.colorSurfaceRaised,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(LucideIcons.circleCheck, color: AppColors.colorSuccess),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                l10n.nfcRegeneratedSuccess,
                style: typography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nfcTagUrlLabel,
              style:
                  typography.bodyStrong.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
                vertical: AppSpacing.space10,
              ),
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBase,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: SelectableText(
                fullUrl,
                style: typography.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBrandSubtle,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
              child: Text(
                l10n.nfcNdefWriteInstructions,
                style: typography.caption.copyWith(
                  color: AppColors.colorTextPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.nfcUrlCopiedToast),
                  backgroundColor: AppColors.colorSuccess,
                ),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(l10n.nfcCopyUrlAction),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.dialogOk),
          ),
        ],
      ),
    );
  }

  void _showReplaceDialog(BuildContext context, WidgetRef ref,
      StationNfcTag tag, AppLocalizations l10n) {
    final nameController =
        TextEditingController(text: '${tag.name} (Replacement)');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.colorSurfaceRaised,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(l10n.nfcReplaceTagTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nfcReplaceTagWarning,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.nfcNewTagNameLabel,
                border: const OutlineInputBorder(),
              ),
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
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                try {
                  final repo = ref.read(nfcTagRepositoryProvider);
                  await repo.replaceStationNfcTag(
                    oldTagId: tag.id,
                    newName: newName,
                  );
                  ref.invalidate(stationNfcTagsProvider(tag.stationId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.nfcTagReplacedSuccess),
                        backgroundColor: AppColors.colorSuccess,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ErrorLocalizer.localize(e, l10n)),
                        backgroundColor: AppColors.colorError,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.nfcReplaceTagConfirm),
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
      return Scaffold(
        body: Center(child: Text(l10n.stationSelectTitle)),
      );
    }

    final tagsAsync = ref.watch(stationNfcTagsProvider(stationId));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        title: Text(l10n.nfcTagsManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: l10n.nfcProvisionNewTitle,
            onPressed: () => _showProvisionDialog(context, ref, stationId),
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.radio,
                        size: 48, color: AppColors.colorSurfaceBrand),
                    const SizedBox(height: AppSpacing.space16),
                    Text(
                      l10n.nfcNoTagsTitle,
                      style: typography.titleLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      l10n.nfcNoTagsDesc,
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium
                          .copyWith(color: AppColors.colorTextSecondary),
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showProvisionDialog(context, ref, stationId),
                      icon: const Icon(LucideIcons.plus),
                      label: Text(l10n.nfcProvisionNewTitle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.colorSurfaceBrand,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.space16),
            itemCount: tags.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.space12),
            itemBuilder: (context, idx) {
              final t = tags[idx];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.space16),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: t.isActive
                        ? AppColors.colorBorderSubtle
                        : AppColors.colorStatusDangerSubtle,
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
                                t.name,
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.colorTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${t.tagIdentifier}',
                                style: typography.caption.copyWith(
                                  color: AppColors.colorTextSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.isActive
                                ? AppColors.colorStatusSuccessSubtle
                                : AppColors.colorStatusDangerSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.isActive
                                ? l10n.nfcTagStatusActive
                                : l10n.nfcTagStatusRevoked,
                            style: typography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: t.isActive
                                  ? AppColors.colorSuccess
                                  : AppColors.colorError,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.lastScannedAt != null
                                ? l10n.nfcLastScanned(dateFormat
                                    .format(t.lastScannedAt!.toLocal()))
                                : l10n.nfcNeverScanned,
                            style: typography.caption.copyWith(
                              color: AppColors.colorTextSecondary,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(t.createdAt.toLocal()),
                          style: typography.caption.copyWith(
                            color: AppColors.colorTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Wrap(
                      spacing: AppSpacing.space8,
                      runSpacing: AppSpacing.space8,
                      alignment: WrapAlignment.end,
                      children: [
                        // Regenerate Token Button
                        OutlinedButton.icon(
                          icon: const Icon(LucideIcons.refreshCw, size: 14),
                          label: Text(l10n.nfcRegenerateTokenAction),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space12,
                              vertical: AppSpacing.space8,
                            ),
                          ),
                          onPressed: () =>
                              _showRegenerateDialog(context, ref, t, l10n),
                        ),
                        TextButton.icon(
                          icon: const Icon(LucideIcons.repeat, size: 14),
                          label: Text(l10n.nfcReplaceAction),
                          onPressed: () =>
                              _showReplaceDialog(context, ref, t, l10n),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            t.isActive
                                ? LucideIcons.ban
                                : LucideIcons.checkCircle,
                            size: 14,
                            color: t.isActive
                                ? AppColors.colorError
                                : AppColors.colorSuccess,
                          ),
                          label: Text(
                            t.isActive
                                ? l10n.nfcRevokeAction
                                : l10n.nfcReactivateAction,
                            style: TextStyle(
                              color: t.isActive
                                  ? AppColors.colorError
                                  : AppColors.colorSuccess,
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final repo = ref.read(nfcTagRepositoryProvider);
                              if (t.isActive) {
                                await repo.revokeStationNfcTag(t.id);
                              } else {
                                await repo.reactivateStationNfcTag(t.id);
                              }
                              ref.invalidate(stationNfcTagsProvider(stationId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t.isActive
                                        ? l10n.nfcTagRevokedToast
                                        : l10n.nfcTagReactivatedToast),
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
