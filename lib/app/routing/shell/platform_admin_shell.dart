import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
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

class PlatformAdminShell extends ConsumerWidget {
  final Widget child;

  const PlatformAdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(stationAccessContextProvider);
    final l10n = AppLocalizations.of(context)!;
    if (!access.canAccessPlatformAdministration) {
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
                Text(l10n.platformUnauthorizedTitle,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  l10n.platformUnauthorizedBody,
                  textAlign: TextAlign.center,
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

class _CompactPlatformShell extends StatelessWidget {
  final Widget child;
  const _CompactPlatformShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).uri.path;
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
        title: const AppBrandMark(size: 26.0),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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

class _WidePlatformShell extends StatelessWidget {
  final Widget child;
  const _WidePlatformShell({required this.child});

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: Row(
        children: [
          Container(
            width: 250.0,
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
                      vertical: AppSpacing.space8),
                  child: AppBrandMark(size: 30.0, showTagline: true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space12,
                      vertical: AppSpacing.space8),
                  child: Text(
                    l10n.platformAdminMode,
                    style: typography.caption.copyWith(
                      color: AppColors.colorTextBrand,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                for (final dest in _destinations)
                  _NavTile(
                    icon: dest.icon,
                    label: dest.label(l10n),
                    selected: location == dest.route ||
                        (dest.route != '/platform' &&
                            location.startsWith(dest.route)),
                    onTap: () => context.go(dest.route),
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
                Icon(icon, size: 18.0, color: AppColors.colorTextPrimary),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
