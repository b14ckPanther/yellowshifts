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

class CompactAppShell extends ConsumerWidget {
  final Widget child;

  const CompactAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    final destinations =
        AppNavigationRegistry.getCompactBottomNavDestinations(access);

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
      appBar: AppBar(
        title: const AppBrandMark(size: 26.0),
        actions: const [
          NotificationBadgeIcon(),
          SizedBox(width: AppSpacing.space4),
          AppStationSwitcher(),
          SizedBox(width: AppSpacing.space8),
        ],
      ),
      body: child,
      bottomNavigationBar: destinations.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.colorSurfaceRaised,
                border: Border(
                  top: BorderSide(
                      color: AppColors.colorBorderSubtle, width: 1.0),
                ),
              ),
              child: SafeArea(
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (idx) {
                    if (idx >= 0 && idx < destinations.length) {
                      context.go(destinations[idx].route);
                    }
                  },
                  backgroundColor: AppColors.colorSurfaceRaised,
                  indicatorColor: AppColors.colorSurfaceBrandAccent,
                  elevation: 0,
                  destinations: destinations.map((d) {
                    return NavigationDestination(
                      icon: Icon(d.icon, size: 20.0),
                      selectedIcon: Icon(
                        d.selectedIcon ?? d.icon,
                        size: 20.0,
                        color: AppColors.colorTextPrimary,
                      ),
                      label: d.labelBuilder(l10n),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
