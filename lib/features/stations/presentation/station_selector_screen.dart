import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/localization/locale_provider.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state_provider.dart';
import '../../../core/permissions/platform_admin_provider.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../domain/station_membership.dart';
import 'active_station_provider.dart';

Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(l10n?.settingsSignOut ?? 'Sign Out'),
      content: Text(
          l10n?.platformLogoutConfirm ?? 'Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l10n?.dialogCancel ?? 'Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: Text(l10n?.settingsSignOut ?? 'Sign Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.colorError,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    ref.read(platformOperatingStationIdProvider.notifier).state = null;
    ref.invalidate(activeStationIdProvider);
    ref.invalidate(currentAuthUserProvider);
    ref.invalidate(userMembershipsStreamProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(isPlatformAdminProvider);
    ref.invalidate(stationAccessContextProvider);
    if (context.mounted) {
      try {
        context.go('/login');
      } catch (_) {}
    }
  }
}

void _refreshMemberships(WidgetRef ref, BuildContext context) {
  ref.invalidate(userMembershipsStreamProvider);
  ref.invalidate(currentAuthUserProvider);
  ref.invalidate(stationAccessContextProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context)?.stationSelectRefresh ??
          'Refreshing...'),
      duration: const Duration(milliseconds: 1200),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class StationSelectorScreen extends ConsumerWidget {
  const StationSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final membershipsAsync = ref.watch(userMembershipsStreamProvider);
    final isPlatformAdmin =
        ref.watch(stationAccessContextProvider).canAccessPlatformAdministration;
    final user = ref.watch(currentAuthUserProvider);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const AppBrandMark(size: 28.0, showTagline: false),
        actions: [
          if (user?.email != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space10,
                    vertical: AppSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.colorSurfaceBrandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.radiusPill),
                    border: Border.all(
                      color: AppColors.colorBorderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.user,
                        size: 13.0,
                        color: AppColors.colorTextBrand,
                      ),
                      const SizedBox(width: AppSpacing.space6),
                      Text(
                        user!.email!,
                        style: typography.caption.copyWith(
                          color: AppColors.colorTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: currentLocale.languageCode == 'he' ? 'English' : 'עברית',
            icon: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.colorBorderSubtle),
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
              child: Text(
                currentLocale.languageCode == 'he' ? 'EN' : 'עב',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.colorTextPrimary,
                ),
              ),
            ),
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
          IconButton(
            tooltip: l10n.stationSelectRefresh,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            color: AppColors.colorTextSecondary,
            onPressed: () => _refreshMemberships(ref, context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
            child: AppButton(
              label: l10n.stationSelectSignOut,
              icon: LucideIcons.logOut,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.small,
              onPressed: () => _confirmAndSignOut(context, ref),
            ),
          ),
        ],
      ),
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
                    child: AppBrandMark(size: 44.0, showTagline: true),
                  ),
                  const SizedBox(height: AppSpacing.space24),
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
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                platformCard,
                                const SizedBox(height: AppSpacing.space12),
                                AppEmptyState(
                                  title: l10n.emptyStationsTitle,
                                  description:
                                      l10n.stationSelectNoStationActionHint,
                                  icon: LucideIcons.building,
                                ),
                                const SizedBox(height: AppSpacing.space24),
                                Wrap(
                                  spacing: AppSpacing.space12,
                                  runSpacing: AppSpacing.space12,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    AppButton(
                                      label: l10n.stationSelectRefresh,
                                      icon: LucideIcons.refreshCw,
                                      variant: AppButtonVariant.primary,
                                      size: AppButtonSize.medium,
                                      onPressed: () =>
                                          _refreshMemberships(ref, context),
                                    ),
                                    AppButton(
                                      label: l10n.stationSelectSignOut,
                                      icon: LucideIcons.logOut,
                                      variant: AppButtonVariant.outline,
                                      size: AppButtonSize.medium,
                                      onPressed: () =>
                                          _confirmAndSignOut(context, ref),
                                    ),
                                    if (isPlatformAdmin)
                                      AppButton(
                                        label: l10n.platformAdminTitle,
                                        icon: LucideIcons.shield,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.medium,
                                        onPressed: () =>
                                            context.go('/platform'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
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
                      error: (err, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppEmptyState(
                              title: l10n.emptyStationsTitle,
                              description: ErrorLocalizer.localize(err, l10n),
                              icon: LucideIcons.alertCircle,
                            ),
                            const SizedBox(height: AppSpacing.space20),
                            Wrap(
                              spacing: AppSpacing.space12,
                              runSpacing: AppSpacing.space12,
                              children: [
                                AppButton(
                                  label: l10n.stationSelectRefresh,
                                  icon: LucideIcons.refreshCw,
                                  variant: AppButtonVariant.primary,
                                  onPressed: () =>
                                      _refreshMemberships(ref, context),
                                ),
                                AppButton(
                                  label: l10n.stationSelectSignOut,
                                  icon: LucideIcons.logOut,
                                  variant: AppButtonVariant.outline,
                                  onPressed: () =>
                                      _confirmAndSignOut(context, ref),
                                ),
                              ],
                            ),
                          ],
                        ),
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
