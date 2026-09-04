import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/system_health_controller.dart';
import '../../domain/models/station_system_health.dart';

class SystemHealthScreen extends ConsumerWidget {
  const SystemHealthScreen({super.key});

  Future<void> _handleCleanup(BuildContext context, WidgetRef ref) async {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataRetentionTitle, style: typography.titleMedium),
        content: Text(l10n.dataRetentionSummary, style: typography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.dataRetentionRunButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ref
          .read(systemHealthControllerProvider.notifier)
          .triggerDataRetentionCleanup();
      if (context.mounted) {
        if (res != null && res['success'] == true) {
          final exportsMarked =
              (res['expired_exports_marked'] as num?)?.toInt() ?? 0;
          final recordsCleaned =
              (res['expired_records_cleaned'] as num?)?.toInt() ?? 0;
          AppFeedback.show(
            context,
            message: l10n.dataRetentionSuccess(exportsMarked, recordsCleaned),
            type: AppFeedbackType.success,
          );
        } else {
          AppFeedback.show(context,
              message: l10n.errorGeneric, type: AppFeedbackType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final healthAsync = ref.watch(systemHealthControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(systemHealthControllerProvider.notifier).loadHealth(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.insetAll16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: l10n.systemHealthTitle,
                      subtitle: l10n.systemHealthSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    healthAsync.when(
                      loading: () => const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.space32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => AppCard(
                        child: Padding(
                          padding: AppSpacing.insetAll16,
                          child: Text(
                            err.toString(),
                            style: typography.bodyMedium
                                .copyWith(color: AppColors.colorStatusDanger),
                          ),
                        ),
                      ),
                      data: (health) => _buildHealthDashboard(
                          context, ref, health, typography, l10n),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthDashboard(
    BuildContext context,
    WidgetRef ref,
    StationSystemHealth health,
    AppTypography typography,
    AppLocalizations l10n,
  ) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Row: NFC Tags & 24h Exports Pipeline
        if (isWide)
          Row(
            children: [
              Expanded(child: _buildNfcFleetCard(health, typography, l10n)),
              const SizedBox(width: AppSpacing.space16),
              Expanded(
                  child: _buildExportPipelineCard(health, typography, l10n)),
            ],
          )
        else ...[
          _buildNfcFleetCard(health, typography, l10n),
          const SizedBox(height: AppSpacing.space16),
          _buildExportPipelineCard(health, typography, l10n),
        ],

        const SizedBox(height: AppSpacing.space16),

        // Anomalies & System Status Card
        _buildAnomaliesCard(health, typography, l10n),

        const SizedBox(height: AppSpacing.space16),

        // Data Lifecycle & Retention Policy Card
        _buildDataRetentionCard(context, ref, typography, l10n),
      ],
    );
  }

  Widget _buildNfcFleetCard(StationSystemHealth health,
      AppTypography typography, AppLocalizations l10n) {
    final hasActiveTags = health.nfcTagsActive > 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.radio,
                color: hasActiveTags
                    ? AppColors.colorStatusSuccess
                    : AppColors.colorStatusWarning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.systemHealthNfcFleet,
                style:
                    typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            l10n.systemHealthNfcActive(
                health.nfcTagsActive, health.nfcTagsTotal),
            style: typography.displayLarge.copyWith(
              color: hasActiveTags
                  ? AppColors.colorStatusSuccess
                  : AppColors.colorStatusWarning,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            health.nfcTagsActive > 0
                ? l10n.systemHealthNfcTagsHealthy
                : l10n.systemHealthNfcNoActiveTags,
            style: typography.caption.copyWith(
              color: health.nfcTagsActive > 0
                  ? AppColors.colorTextMuted
                  : AppColors.colorStatusWarning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportPipelineCard(StationSystemHealth health,
      AppTypography typography, AppLocalizations l10n) {
    final isClean = health.exportsFailed24h == 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileSpreadsheet,
                  color: AppColors.colorActionPrimary, size: 20),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.systemHealthExportPipeline,
                style:
                    typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            l10n.systemHealthExportsSummary(
                health.exportsTotal24h, health.exportsFailed24h),
            style: typography.displayLarge.copyWith(
              color: isClean
                  ? AppColors.colorTextPrimary
                  : AppColors.colorStatusDanger,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            l10n.systemHealthDefenseSubtitle,
            style: typography.caption.copyWith(color: AppColors.colorTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesCard(StationSystemHealth health,
      AppTypography typography, AppLocalizations l10n) {
    final hasAnomalies = health.hasAnomalies;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasAnomalies
                    ? LucideIcons.alertTriangle
                    : LucideIcons.checkCircle2,
                color: hasAnomalies
                    ? AppColors.colorStatusDanger
                    : AppColors.colorStatusSuccess,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.systemHealthAnomalies,
                style:
                    typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          if (!hasAnomalies)
            Container(
              padding: AppSpacing.insetAll12,
              decoration: const BoxDecoration(
                color: AppColors.colorStatusSuccessSubtle,
                borderRadius: AppRadius.borderMd,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldCheck,
                      color: AppColors.colorStatusSuccess, size: 18),
                  const SizedBox(width: AppSpacing.space8),
                  Text(
                    l10n.systemHealthNoAnomalies,
                    style: typography.bodyMedium
                        .copyWith(color: AppColors.colorStatusSuccess),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                if (health.staleOpenSessions > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.clockAlert,
                        color: AppColors.colorStatusDanger),
                    title: Text(
                      l10n.systemHealthStaleSessions(health.staleOpenSessions),
                      style: typography.bodyStrong
                          .copyWith(color: AppColors.colorStatusDanger),
                    ),
                    subtitle: Text(
                      l10n.systemHealthStaleSessionsSubtitle,
                      style: typography.caption,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDataRetentionCard(BuildContext context, WidgetRef ref,
      AppTypography typography, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.archive,
                  color: AppColors.colorActionPrimary, size: 20),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.dataRetentionTitle,
                style:
                    typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            l10n.dataRetentionSummary,
            style: typography.bodyMedium
                .copyWith(color: AppColors.colorTextSecondary),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton.icon(
            onPressed: () => _handleCleanup(context, ref),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: Text(l10n.dataRetentionRunButton),
          ),
        ],
      ),
    );
  }
}
