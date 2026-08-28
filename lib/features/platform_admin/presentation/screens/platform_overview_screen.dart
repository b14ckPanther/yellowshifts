import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../platform_admin_providers.dart';

class PlatformOverviewScreen extends ConsumerWidget {
  const PlatformOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(platformOverviewProvider);
    const typography = AppTypography();

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: l10n.platformOverviewTitle,
              subtitle: l10n.platformOverviewSubtitle,
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(ErrorLocalizer.localize(e, l10n)),
                ),
                data: (overview) {
                  final cards = [
                    (
                      l10n.platformMetricTotalStations,
                      overview.totalStations,
                      LucideIcons.building2
                    ),
                    (
                      l10n.platformMetricActiveStations,
                      overview.activeStations,
                      LucideIcons.circleCheck
                    ),
                    (
                      l10n.platformMetricInactiveStations,
                      overview.inactiveStations,
                      LucideIcons.circleOff
                    ),
                    (
                      l10n.platformMetricActiveMemberships,
                      overview.activeMemberships,
                      LucideIcons.users
                    ),
                    (
                      l10n.platformMetricStationAdmins,
                      overview.stationAdminCount,
                      LucideIcons.shield
                    ),
                    (
                      l10n.platformMetricShiftManagers,
                      overview.shiftManagerCount,
                      LucideIcons.userCheck
                    ),
                    (
                      l10n.platformMetricKiosksOnline,
                      overview.kiosksOnline,
                      LucideIcons.wifi
                    ),
                    (
                      l10n.platformMetricKiosksOffline,
                      overview.kiosksOffline,
                      LucideIcons.wifiOff
                    ),
                    (
                      l10n.platformMetricAlerts,
                      overview.operationalAlertCount,
                      LucideIcons.triangleAlert
                    ),
                  ];
                  final width = MediaQuery.sizeOf(context).width;
                  final cross = width >= 1280
                      ? 4
                      : width >= 768
                          ? 3
                          : 2;
                  return ListView(
                    padding: AppSpacing.insetHorizontal16,
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: AppSpacing.space12,
                          crossAxisSpacing: AppSpacing.space12,
                          mainAxisExtent: 148,
                        ),
                        itemBuilder: (context, i) {
                          final card = cards[i];
                          return AppSurface(
                            child: FittedBox(
                              alignment: AlignmentDirectional.topStart,
                              fit: BoxFit.scaleDown,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(card.$3,
                                      size: 18.0,
                                      color: AppColors.colorTextBrand),
                                  const SizedBox(height: AppSpacing.space8),
                                  Text('${card.$2}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.titleLarge.copyWith(
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(card.$1,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.caption.copyWith(
                                          color: AppColors.colorTextSecondary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.space24),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => context.go('/platform/stations'),
                          icon: const Icon(LucideIcons.arrowLeft, size: 16),
                          label: Text(l10n.platformNavStations),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space32),
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
