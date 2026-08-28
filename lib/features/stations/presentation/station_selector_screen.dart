import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../domain/station_membership.dart';
import 'active_station_provider.dart';

class StationSelectorScreen extends ConsumerWidget {
  const StationSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final membershipsAsync = ref.watch(userMembershipsStreamProvider);
    final isPlatformAdmin =
        ref.watch(stationAccessContextProvider).canAccessPlatformAdministration;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640.0),
            child: Padding(
              padding: AppSpacing.insetAll24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: AppBrandMark(size: 40.0, showTagline: true),
                  ),
                  const SizedBox(height: AppSpacing.space32),
                  Text(
                    l10n.stationSelectTitle,
                    textAlign: TextAlign.center,
                    style: typography.titleLarge.copyWith(
                      color: AppColors.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    l10n.stationSelectSubtitle,
                    textAlign: TextAlign.center,
                    style: typography.bodyMedium.copyWith(
                      color: AppColors.colorTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  Expanded(
                    child: membershipsAsync.when(
                      data: (memberships) {
                        final platformCard = isPlatformAdmin
                            ? Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.space12),
                                child: AppCard(
                                  onTap: () => context.go('/platform'),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48.0,
                                        height: 48.0,
                                        decoration: const BoxDecoration(
                                          color:
                                              AppColors.colorSurfaceBrandSubtle,
                                          borderRadius: AppRadius.borderMd,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          LucideIcons.shield,
                                          size: 24.0,
                                          color: AppColors.colorTextBrand,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.space16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.platformAdminTitle,
                                              style: typography.titleMedium
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              l10n.platformAdminMode,
                                              style: typography.caption
                                                  .copyWith(
                                                      color: AppColors
                                                          .colorTextMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(LucideIcons.arrowRight,
                                          color: AppColors.colorTextMuted),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();

                        if (memberships.isEmpty) {
                          return Column(
                            children: [
                              platformCard,
                              Expanded(
                                child: AppEmptyState(
                                  title: l10n.emptyStationsTitle,
                                  description: l10n.emptyStationsDescription,
                                  icon: LucideIcons.building,
                                ),
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          itemCount:
                              memberships.length + (isPlatformAdmin ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.space12),
                          itemBuilder: (context, index) {
                            if (isPlatformAdmin && index == 0) {
                              return platformCard;
                            }
                            final membership = memberships[
                                isPlatformAdmin ? index - 1 : index];
                            final station = membership.station;
                            final stationName =
                                station?.name ?? l10n.stationSelectTitle;
                            final stationCode = station?.code ?? 'N/A';

                            return AppCard(
                              onTap: () {
                                ref
                                    .read(activeStationIdProvider.notifier)
                                    .selectStation(membership.stationId);
                                context.go('/dashboard');
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 48.0,
                                    height: 48.0,
                                    decoration: BoxDecoration(
                                      color: AppColors.colorSurfaceBrandSubtle,
                                      borderRadius: AppRadius.borderMd,
                                      border: Border.all(
                                        color:
                                            AppColors.colorSurfaceBrandAccent,
                                        width: 1.0,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      LucideIcons.building2,
                                      size: 24.0,
                                      color: AppColors.colorTextBrand,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stationName,
                                          style:
                                              typography.titleMedium.copyWith(
                                            color: AppColors.colorTextPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: AppSpacing.space4),
                                        Text(
                                          '${l10n.dashboardStationCode}: $stationCode • ${station?.timezone ?? "Asia/Jerusalem"}',
                                          style: typography.caption.copyWith(
                                            color: AppColors.colorTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildRoleBadge(membership.role, l10n),
                                  const SizedBox(width: AppSpacing.space12),
                                  const Icon(
                                    LucideIcons.arrowRight,
                                    size: 18.0,
                                    color: AppColors.colorTextMuted,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => ListView.separated(
                        itemCount: 3,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.space12),
                        itemBuilder: (_, __) => const AppSkeletonCard(),
                      ),
                      error: (err, _) => AppEmptyState(
                        title: l10n.emptyStationsTitle,
                        description: ErrorLocalizer.localize(err, l10n),
                        icon: LucideIcons.alertCircle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(StationRole role, AppLocalizations l10n) {
    switch (role) {
      case StationRole.admin:
        return AppStatusBadge(
          label: l10n.roleAdmin,
          variant: AppBadgeVariant.brand,
          icon: LucideIcons.shieldCheck,
        );
      case StationRole.shiftManager:
        return AppStatusBadge(
          label: l10n.roleShiftManager,
          variant: AppBadgeVariant.info,
          icon: LucideIcons.userCheck,
        );
      case StationRole.employee:
        return AppStatusBadge(
          label: l10n.roleEmployee,
          variant: AppBadgeVariant.neutral,
          icon: LucideIcons.user,
        );
    }
  }
}
