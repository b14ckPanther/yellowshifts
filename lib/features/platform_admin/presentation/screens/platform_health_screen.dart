import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../platform_admin_providers.dart';

class PlatformHealthScreen extends ConsumerWidget {
  const PlatformHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();
    final async = ref.watch(platformOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: l10n.platformHealthTitle,
              subtitle: l10n.platformHealthSubtitle,
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(ErrorLocalizer.localize(e, l10n))),
                data: (overview) {
                  final rows = [
                    (l10n.platformMetricNfcActive, '${overview.nfcTagsActive}'),
                    (l10n.platformMetricNfcTotal, '${overview.nfcTagsTotal}'),
                    (
                      l10n.platformMetricAlerts,
                      '${overview.operationalAlertCount}'
                    ),
                    (
                      l10n.platformMetricInactiveStations,
                      '${overview.inactiveStations}'
                    ),
                  ];
                  return ListView(
                    padding: AppSpacing.insetHorizontal16,
                    children: [
                      for (final row in rows) ...[
                        AppSurface(
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(row.$1,
                                      style: typography.bodyMedium)),
                              Text(row.$2, style: typography.bodyStrong),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
