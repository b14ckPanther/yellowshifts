import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/localization/locale_provider.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';

class _PlatformDest {
  final String route;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  const _PlatformDest(this.route, this.icon, this.label);
}

const _destinations = <_PlatformDest>[
  _PlatformDest('/platform', LucideIcons.layoutDashboard, _overview),
  _PlatformDest('/platform/stations', LucideIcons.building2, _stations),
  _PlatformDest('/platform/health', LucideIcons.activity, _health),
  _PlatformDest('/platform/audit', LucideIcons.fileSearch, _audit),
];

String _overview(AppLocalizations l10n) => l10n.platformNavOverview;
String _stations(AppLocalizations l10n) => l10n.platformNavStations;
String _health(AppLocalizations l10n) => l10n.platformNavHealth;
String _audit(AppLocalizations l10n) => l10n.platformNavAudit;

Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(l10n?.settingsSignOut ?? 'Sign Out'),
      content: Text(l10n?.platformLogoutConfirm ??
          'Are you sure you want to sign out?'),
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
    if (context.mounted) {
      try {
        context.go('/login');
      } catch (_) {}
    }
  }
}

class PlatformAdminShell extends ConsumerWidget {
  final Widget child;

  const PlatformAdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(stationAccessContextProvider);
    final l10n = AppLocalizations.of(context);

    // If user is unauthenticated, render a clean surface while router redirects to /login
    if (!access.isAuthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: SizedBox.shrink(),
      );
    }

    if (!access.canAccessPlatformAdministration) {
      const typography = AppTypography();
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: Center(
          child: Padding(
            padding: AppSpacing.insetAll24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.shieldOff,
                    size: 40.0, color: AppColors.colorTextMuted),
                const SizedBox(height: AppSpacing.space16),
                Text(
                  l10n?.platformUnauthorizedTitle ??
                      'Platform Access Restricted',
                  style: typography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.colorTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  l10n?.platformUnauthorizedBody ??
                      'You do not have active platform administrator privileges.',
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.colorTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space24),
                ElevatedButton.icon(
                  onPressed: () {
                    try {
                      context.go('/dashboard');
                    } catch (_) {}
                  },
                  icon: const Icon(LucideIcons.arrowLeft, size: 16),
                  label: Text(l10n?.navDashboard ?? 'Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorSurfaceBrand,
                    foregroundColor: AppColors.colorTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AdaptiveBuilder(
      builder: (context, sizeClass) {
        if (sizeClass == AppSizeClass.compact) {
          return _CompactPlatformShell(child: child);
        }
        return _WidePlatformShell(child: child);
      },
    );
  }
}

class _CompactPlatformShell extends ConsumerWidget {
  final Widget child;
  const _CompactPlatformShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    String location;
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {
      location = '/platform';
    }
    final currentLocale = ref.watch(localeProvider);

    int selected = 0;
    for (int i = 0; i < _destinations.length; i++) {
      if (location == _destinations[i].route ||
          (i > 0 && location.startsWith(_destinations[i].route))) {
        selected = i;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        title: const AppBrandMark(size: 24.0),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.globe, size: 18.0),
            tooltip: currentLocale.languageCode == 'he'
                ? 'Switch to English'
                : 'עבור לעברית',
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
          IconButton(
            icon: const Icon(LucideIcons.store, size: 18.0),
            tooltip: l10n.platformWorkspaceSwitch,
            onPressed: () => context.go('/dashboard'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, size: 18.0),
            color: AppColors.colorError,
            tooltip: l10n.settingsSignOut,
            onPressed: () => _confirmAndSignOut(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              l10n.platformAdminMode,
              style: const AppTypography().caption.copyWith(
                    color: AppColors.colorTextBrand,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(_destinations[i].route),
        destinations: [
          for (final dest in _destinations)
            NavigationDestination(
              icon: Icon(dest.icon, size: 20.0),
              label: dest.label(l10n),
            ),
        ],
      ),
    );
  }
}

class _WidePlatformShell extends ConsumerWidget {
  final Widget child;
  const _WidePlatformShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    String location;
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {
      location = '/platform';
    }
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: Row(
        children: [
          Container(
            width: 260.0,
            decoration: const BoxDecoration(
              color: AppColors.colorSurfaceRaised,
              border: Border(
                right: BorderSide(color: AppColors.colorBorderSubtle),
              ),
            ),
            padding: AppSpacing.insetAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4),
                  child: AppBrandMark(size: 28.0, showTagline: true),
                ),
                const SizedBox(height: AppSpacing.space12),

                // Super Admin Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space12,
                      vertical: AppSpacing.space8),
                  decoration: BoxDecoration(
                    color: AppColors.colorSurfaceBrandSubtle,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: AppColors.colorBorderBrand,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck,
                          size: 16.0, color: AppColors.colorTextBrand),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          l10n.platformAdminMode,
                          style: typography.caption.copyWith(
                            color: AppColors.colorTextBrand,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),

                // Platform Nav Links
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final dest in _destinations)
                          _NavTile(
                            icon: dest.icon,
                            label: dest.label(l10n),
                            selected: location == dest.route ||
                                (dest.route != '/platform' &&
                                    location.startsWith(dest.route)),
                            onTap: () => context.go(dest.route),
                          ),
                        const SizedBox(height: AppSpacing.space12),
                        const Divider(color: AppColors.colorBorderSubtle),
                        const SizedBox(height: AppSpacing.space8),

                        // Switch to Station Workspace
                        _ActionTile(
                          icon: LucideIcons.store,
                          label: l10n.platformWorkspaceSwitch,
                          color: AppColors.colorTextSecondary,
                          onTap: () => context.go('/dashboard'),
                        ),

                        // Language Switcher
                        _ActionTile(
                          icon: LucideIcons.globe,
                          label: currentLocale.languageCode == 'he'
                              ? 'Switch to English'
                              : 'עבור לעברית',
                          color: AppColors.colorTextSecondary,
                          onTap: () =>
                              ref.read(localeProvider.notifier).toggleLocale(),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: AppColors.colorBorderSubtle),
                const SizedBox(height: AppSpacing.space8),

                // User Profile & Logout Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                      vertical: AppSpacing.space4),
                  child: Row(
                    children: [
                      const AppAvatar(name: 'Admin', size: 36.0),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.platformSuperAdminRole,
                              style: typography.bodyStrong
                                  .copyWith(fontSize: 13.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.platformAdminTitle,
                              style: typography.caption.copyWith(
                                color: AppColors.colorTextBrand,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.logOut, size: 18.0),
                        color: AppColors.colorError,
                        tooltip: l10n.settingsSignOut,
                        onPressed: () => _confirmAndSignOut(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color:
            selected ? AppColors.colorSurfaceBrandSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12, vertical: AppSpacing.space12),
            child: Row(
              children: [
                Icon(icon,
                    size: 18.0,
                    color: selected
                        ? AppColors.colorTextBrand
                        : AppColors.colorTextPrimary),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.colorTextBrand
                          : AppColors.colorTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12, vertical: AppSpacing.space10),
            child: Row(
              children: [
                Icon(icon,
                    size: 18.0, color: color ?? AppColors.colorTextSecondary),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: color ?? AppColors.colorTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
