import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state_provider.dart';
import '../../../core/permissions/platform_admin_provider.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../app/localization/locale_provider.dart';
import '../../stations/presentation/active_station_provider.dart';

import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    final activeMembership = ref.watch(activeMembershipProvider);
    final locale = ref.watch(localeProvider);
    final station = activeMembership?.station;
    final isAdmin = activeMembership?.role.isAdmin ?? false;
    final isPlatformAdmin =
        ref.watch(stationAccessContextProvider).canAccessPlatformAdministration;

    final profile = profileAsync.value;
    final userName = profile?.fullName ?? 'Operator';
    final userPhone = profile?.phone ?? '';

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.settingsTitle,
                subtitle: l10n.settingsSubtitle,
              ),
              Padding(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  children: [
                    // Profile Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsUserProfile,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          Row(
                            children: [
                              AppAvatar(name: userName, size: 48.0),
                              const SizedBox(width: AppSpacing.space12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: typography.bodyStrong
                                          .copyWith(fontSize: 15.0),
                                    ),
                                    if (userPhone.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.space4),
                                      Text(
                                        l10n.settingsUserPhone(userPhone),
                                        style: typography.caption.copyWith(
                                            color: AppColors.colorTextMuted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.colorBorderSubtle),
                          _buildNavTile(
                            icon: LucideIcons.bellRing,
                            title: l10n.settingsNotifications,
                            subtitle: l10n.settingsNotificationsSubtitle,
                            onTap: () => context.go('/settings/notifications'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Station Operations & Management (Admin Only)
                    if (isAdmin) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsStationAdmin,
                              style: typography.titleMedium
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.space12),
                            _buildNavTile(
                              icon: LucideIcons.sliders,
                              title: l10n.settingsOperationalParams,
                              subtitle: l10n.settingsOperationalParamsSubtitle,
                              onTap: () => context.go('/settings/station'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.radio,
                              title: l10n.settingsNfcTags,
                              subtitle: l10n.settingsNfcTagsSubtitle,
                              onTap: () => context.go('/settings/nfc-tags'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.clock,
                              title: l10n.settingsShiftTemplates,
                              subtitle: l10n.settingsShiftTemplatesSubtitle,
                              onTap: () => context.go('/settings/shifts'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.userCheck,
                              title: l10n.settingsShiftManagerCaps,
                              subtitle: l10n.settingsShiftManagerCapsSubtitle,
                              onTap: () => context.go('/settings/permissions'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.fileSpreadsheet,
                              title: l10n.settingsExportCenter,
                              subtitle: l10n.settingsExportCenterSubtitle,
                              onTap: () => context.go('/reports/exports'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.fileSearch,
                              title: l10n.settingsAuditCenter,
                              subtitle: l10n.settingsAuditCenterSubtitle,
                              onTap: () => context.go('/settings/audit'),
                            ),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildNavTile(
                              icon: LucideIcons.activity,
                              title: l10n.settingsSystemHealth,
                              subtitle: l10n.settingsSystemHealthSubtitle,
                              onTap: () =>
                                  context.go('/settings/system-health'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space16),
                    ],

                    // Current Station Details Card
                    if (station != null) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsCurrentStationDetails,
                              style: typography.titleMedium
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.space12),
                            _buildInfoRow(
                                l10n.settingsStationName, station.name),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildInfoRow(
                                l10n.settingsStationCode, station.code),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildInfoRow(
                                l10n.settingsStationTimezone, station.timezone),
                            const Divider(color: AppColors.colorBorderSubtle),
                            _buildInfoRow(
                                l10n.settingsStationLocale, station.locale),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space16),
                    ],

                    if (isPlatformAdmin) ...[
                      AppCard(
                        onTap: () => context.go('/platform'),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.shield,
                                color: AppColors.colorTextBrand),
                            const SizedBox(width: AppSpacing.space12),
                            Expanded(
                              child: Text(
                                l10n.platformAdminTitle,
                                style: typography.bodyStrong,
                              ),
                            ),
                            const Icon(LucideIcons.arrowRight, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space16),
                    ],

                    // Localization / Language Switcher Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsLanguageDirection,
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          Wrap(
                            spacing: AppSpacing.space16,
                            runSpacing: AppSpacing.space12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 240.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locale.languageCode == 'he'
                                          ? 'עברית (RTL - Heebo)'
                                          : 'English (LTR - Ubuntu)',
                                      style: typography.bodyStrong,
                                    ),
                                    Text(
                                      locale.languageCode == 'he'
                                          ? 'טיפוגרפיה וכיווניות מותאמות אוטומטית'
                                          : 'Typography automatically adapts per locale',
                                      style: typography.caption.copyWith(
                                          color: AppColors.colorTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              AppButton(
                                label: locale.languageCode == 'he'
                                    ? 'Switch to English'
                                    : 'עבור לעברית',
                                variant: AppButtonVariant.outline,
                                size: AppButtonSize.small,
                                icon: LucideIcons.globe,
                                onPressed: () => ref
                                    .read(localeProvider.notifier)
                                    .toggleLocale(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Sign Out
                    AppButton(
                      label: l10n.settingsSignOut,
                      variant: AppButtonVariant.destructive,
                      isFullWidth: true,
                      size: AppButtonSize.large,
                      icon: LucideIcons.logOut,
                      onPressed: () async {
                        try {
                          await ref.read(authRepositoryProvider).signOut();
                        } catch (_) {}
                        ref
                            .read(platformOperatingStationIdProvider.notifier)
                            .state = null;
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
                      },
                    ),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const typography = AppTypography();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
        child: Row(
          children: [
            Icon(icon, size: 20.0, color: AppColors.colorTextPrimary),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: typography.bodyStrong),
                  const SizedBox(height: AppSpacing.space2),
                  Text(subtitle,
                      style: typography.caption
                          .copyWith(color: AppColors.colorTextMuted)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18.0, color: AppColors.colorTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    const typography = AppTypography();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: typography.bodyMedium
                      .copyWith(color: AppColors.colorTextSecondary))),
          const SizedBox(width: AppSpacing.space8),
          Flexible(
              child: Text(value,
                  style: typography.bodyStrong
                      .copyWith(color: AppColors.colorTextPrimary))),
        ],
      ),
    );
  }
}
