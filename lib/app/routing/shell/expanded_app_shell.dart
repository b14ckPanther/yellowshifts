import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/auth/auth_state_provider.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../core/design_system/motion/app_motion.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/stations/presentation/widgets/app_station_switcher.dart';
import '../../../features/notifications/presentation/widgets/notification_badge_icon.dart';
import '../navigation_registry.dart';

class ExpandedAppShell extends ConsumerWidget {
  final Widget child;

  const ExpandedAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    final access = ref.watch(stationAccessContextProvider);
    final groupedDestinations =
        AppNavigationRegistry.getGroupedDestinations(access);

    String location;
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {
      location = '/dashboard';
    }
    final userName = profileAsync.value?.fullName ?? l10n.roleEmployee;

    final workspaceItems = groupedDestinations[NavSection.workspace] ?? [];
    final managementItems = groupedDestinations[NavSection.management] ?? [];
    final generalItems = groupedDestinations[NavSection.general] ?? [];

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: Row(
        children: [
          // Persistent Sidebar
          Container(
            width: 250.0,
            decoration: const BoxDecoration(
              color: AppColors.colorSurfaceRaised,
              border: Border(
                right:
                    BorderSide(color: AppColors.colorBorderSubtle, width: 1.0),
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
                const SizedBox(height: AppSpacing.space16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Workspace Section
                        if (workspaceItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space12,
                                vertical: AppSpacing.space4),
                            child: Text(
                              l10n.navSectionWorkspace.toUpperCase(),
                              style: typography.caption.copyWith(
                                color: AppColors.colorTextMuted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontSize: 11.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          ...workspaceItems.map((d) {
                            return _SidebarItem(
                              icon: d.icon,
                              label: d.labelBuilder(l10n),
                              isSelected: location.startsWith(d.route),
                              onTap: () => context.go(d.route),
                            );
                          }),
                          const SizedBox(height: AppSpacing.space12),
                        ],

                        // Management Section
                        if (managementItems.isNotEmpty) ...[
                          const Divider(
                              color: AppColors.colorBorderSubtle, height: 16.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space12,
                                vertical: AppSpacing.space4),
                            child: Text(
                              l10n.navSectionManagement.toUpperCase(),
                              style: typography.caption.copyWith(
                                color: AppColors.colorTextMuted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontSize: 11.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          ...managementItems.map((d) {
                            return _SidebarItem(
                              icon: d.icon,
                              label: d.labelBuilder(l10n),
                              isSelected: location.startsWith(d.route),
                              onTap: () => context.go(d.route),
                            );
                          }),
                          const SizedBox(height: AppSpacing.space12),
                        ],

                        // General Section (Notifications, etc)
                        if (generalItems
                            .where((d) => d.route != '/settings')
                            .isNotEmpty) ...[
                          const Divider(
                              color: AppColors.colorBorderSubtle, height: 16.0),
                          ...generalItems
                              .where((d) => d.route != '/settings')
                              .map((d) {
                            return _SidebarItem(
                              icon: d.icon,
                              label: d.labelBuilder(l10n),
                              isSelected: location.startsWith(d.route),
                              onTap: () => context.go(d.route),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(color: AppColors.colorBorderSubtle),
                _SidebarItem(
                  icon: LucideIcons.settings,
                  label: l10n.navSettings,
                  isSelected: location.startsWith('/settings'),
                  onTap: () => context.go('/settings'),
                ),
                const SizedBox(height: AppSpacing.space8),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
                  child: Row(
                    children: [
                      AppAvatar(name: userName, size: 36.0),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: Text(
                          userName,
                          style: typography.bodyStrong.copyWith(fontSize: 13.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Workspace
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64.0,
                  padding: AppSpacing.insetHorizontal24,
                  decoration: const BoxDecoration(
                    color: AppColors.colorSurfaceRaised,
                    border: Border(
                      bottom: BorderSide(
                          color: AppColors.colorBorderSubtle, width: 1.0),
                    ),
                  ),
                  child: const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NotificationBadgeIcon(),
                        SizedBox(width: AppSpacing.space12),
                        AppStationSwitcher(),
                      ],
                    ),
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

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.durationFast,
            curve: AppMotion.curveStandard,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12, vertical: AppSpacing.space10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.colorSurfaceBrandAccent
                  : (_isHovered
                      ? AppColors.colorSurfaceBase
                      : Colors.transparent),
              borderRadius: AppRadius.borderMd,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18.0,
                  color: widget.isSelected
                      ? AppColors.colorTextPrimary
                      : AppColors.colorTextSecondary,
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: typography.bodyMedium.copyWith(
                      fontWeight:
                          widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: widget.isSelected
                          ? AppColors.colorTextPrimary
                          : AppColors.colorTextSecondary,
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
