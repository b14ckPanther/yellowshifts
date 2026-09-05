import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../core/design_system/widgets/app_connectivity_banner.dart';
import '../../../core/design_system/widgets/app_update_banner.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../features/authentication/presentation/login_screen.dart';
import '../../../features/platform_admin/presentation/widgets/platform_scope_banner.dart';
import 'compact_app_shell.dart';
import 'medium_app_shell.dart';
import 'expanded_app_shell.dart';

class AdaptiveAppShell extends ConsumerWidget {
  final Widget child;

  const AdaptiveAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(stationAccessContextProvider);

    if (!access.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          try {
            context.go('/login');
          } catch (_) {}
        }
      });
      return const LoginScreen();
    }

    final shellBody = Column(
      children: [
        const AppConnectivityBanner(),
        const AppUpdateBanner(),
        const PlatformScopeBanner(),
        Expanded(child: child),
      ],
    );

    return AdaptiveBuilder(
      builder: (context, sizeClass) {
        switch (sizeClass) {
          case AppSizeClass.compact:
            return CompactAppShell(child: shellBody);
          case AppSizeClass.medium:
            return MediumAppShell(child: shellBody);
          case AppSizeClass.expanded:
            return ExpandedAppShell(child: shellBody);
        }
      },
    );
  }
}
