import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../domain/models/station_nfc_tag.dart';
import 'providers/nfc_providers.dart';
import 'widgets/nfc_provision_dialog.dart';

class ManagerNfcTagsScreen extends ConsumerWidget {
  const ManagerNfcTagsScreen({super.key});

  void _showProvisionDialog(
      BuildContext context, WidgetRef ref, String stationId) {
    showDialog(
      context: context,
      builder: (_) => NfcProvisionDialog(stationId: stationId),
    );
  }

  void _showReplaceDialog(BuildContext context, WidgetRef ref,
      StationNfcTag tag, AppLocalizations l10n) {
    final nameController = TextEditingController(text: '${tag.name} (Replacement)');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
                                ? l10n.nfcLastScanned(
                                    dateFormat.format(t.lastScannedAt!.toLocal()))
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(LucideIcons.repeat, size: 16),
                          label: Text(l10n.nfcReplaceAction),
                          onPressed: () =>
                              _showReplaceDialog(context, ref, t, l10n),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        TextButton.icon(
                          icon: Icon(
                            t.isActive
                                ? LucideIcons.ban
                                : LucideIcons.checkCircle,
                            size: 16,
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
                              ref.invalidate(
                                  stationNfcTagsProvider(stationId));
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
                                    content: Text(
                                        ErrorLocalizer.localize(e, l10n)),
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
