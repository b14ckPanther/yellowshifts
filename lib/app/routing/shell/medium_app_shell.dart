import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/stations/presentation/widgets/app_station_switcher.dart';
import '../../../features/notifications/presentation/widgets/notification_badge_icon.dart';

import '../navigation_registry.dart';

class MediumAppShell extends ConsumerWidget {
  final Widget child;

  const MediumAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    final destinations =
        AppNavigationRegistry.getAuthorizedDestinations(access);

    String location;
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {
      location = '/dashboard';
    }

    int selectedIndex = 0;
    for (int i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].route)) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: Row(
        children: [
          if (destinations.isNotEmpty) ...[
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) {
                if (idx >= 0 && idx < destinations.length) {
                  context.go(destinations[idx].route);
                }
              },
              backgroundColor: AppColors.colorSurfaceRaised,
              indicatorColor: AppColors.colorSurfaceBrandAccent,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.space16),
                child: AppBrandMark(size: 28.0),
              ),
              labelType: NavigationRailLabelType.all,
              destinations: destinations.map((d) {
                return NavigationRailDestination(
                  icon: Icon(d.icon, size: 20.0),
                  selectedIcon: Icon(
                    d.selectedIcon ?? d.icon,
                    size: 20.0,
                    color: AppColors.colorTextPrimary,
                  ),
                  label: Text(d.labelBuilder(l10n)),
                );
              }).toList(),
            ),
            const VerticalDivider(
                width: 1.0, color: AppColors.colorBorderSubtle),
          ],
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60.0,
                  padding: AppSpacing.insetHorizontal16,
                  decoration: const BoxDecoration(
                    color: AppColors.colorSurfaceRaised,
                    border: Border(
                      bottom: BorderSide(
                          color: AppColors.colorBorderSubtle, width: 1.0),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NotificationBadgeIcon(),
                      SizedBox(width: AppSpacing.space8),
                      AppStationSwitcher(),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
