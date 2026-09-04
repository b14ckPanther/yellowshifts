import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/permissions/station_access_context.dart';
import '../../l10n/app_localizations.dart';

enum NavSection {
  workspace,
  management,
  general,
}

class AppNavDestination {
  final String route;
  final String Function(AppLocalizations l10n) labelBuilder;
  final IconData icon;
  final IconData? selectedIcon;
  final bool Function(StationAccessContext access) isVisible;
  final NavSection section;
  final int
      mobilePriority; // Higher = preferred on compact bottom bar (0 = not on primary bottom bar)

  const AppNavDestination({
    required this.route,
    required this.labelBuilder,
    required this.icon,
    this.selectedIcon,
    required this.isVisible,
    required this.section,
    this.mobilePriority = 0,
  });
}

/// Canonical navigation registry for YellowShifts.
/// Shared identically across Compact, Medium, and Expanded app shells.
class AppNavigationRegistry {
  static const List<AppNavDestination> destinations = [
    // -------------------------------------------------------------------------
    // Workspace Section
    // -------------------------------------------------------------------------
    AppNavDestination(
      route: '/dashboard',
      labelBuilder: _labelDashboard,
      icon: LucideIcons.layoutDashboard,
      isVisible: _isVisibleActive,
      section: NavSection.workspace,
      mobilePriority: 100,
    ),
    AppNavDestination(
      route: '/schedule',
      labelBuilder: _labelSchedule,
      icon: LucideIcons.calendar,
      isVisible: _isVisibleSchedule,
      section: NavSection.workspace,
      mobilePriority: 90,
    ),
    AppNavDestination(
      route: '/hours',
      labelBuilder: _labelHours,
      icon: LucideIcons.timer,
      isVisible: _isVisibleHours,
      section: NavSection.workspace,
      mobilePriority: 80,
    ),
    AppNavDestination(
      route: '/availability',
      labelBuilder: _labelAvailability,
      icon: LucideIcons.calendarCheck,
      isVisible: _isVisibleAvailability,
      section: NavSection.workspace,
      mobilePriority: 70,
    ),
    AppNavDestination(
      route: '/attendance',
      labelBuilder: _labelAttendance,
      icon: LucideIcons.clock,
      isVisible: _isVisibleAttendance,
      section: NavSection.workspace,
      mobilePriority: 85,
    ),

    // -------------------------------------------------------------------------
    // Management Section (Privileged)
    // -------------------------------------------------------------------------
    AppNavDestination(
      route: '/reports',
      labelBuilder: _labelReports,
      icon: LucideIcons.barChart3,
      isVisible: _isVisibleReports,
      section: NavSection.management,
      mobilePriority: 60,
    ),
    AppNavDestination(
      route: '/reports/exports',
      labelBuilder: _labelExports,
      icon: LucideIcons.fileSpreadsheet,
      isVisible: _isVisibleExports,
      section: NavSection.management,
      mobilePriority: 0,
    ),
    AppNavDestination(
      route: '/employees',
      labelBuilder: _labelEmployees,
      icon: LucideIcons.users,
      isVisible: _isVisibleEmployees,
      section: NavSection.management,
      mobilePriority: 75,
    ),
    AppNavDestination(
      route: '/settings/shifts',
      labelBuilder: _labelShiftTemplates,
      icon: LucideIcons.calendarClock,
      isVisible: _isVisibleShiftTemplates,
      section: NavSection.management,
      mobilePriority: 0,
    ),
    AppNavDestination(
      route: '/settings/nfc-tags',
      labelBuilder: _labelNfcTags,
      icon: LucideIcons.radio,
      isVisible: _isVisibleNfcTags,
      section: NavSection.management,
      mobilePriority: 0,
    ),
    AppNavDestination(
      route: '/settings/audit',
      labelBuilder: _labelAuditCenter,
      icon: LucideIcons.fileSearch,
      isVisible: _isVisibleAuditCenter,
      section: NavSection.management,
      mobilePriority: 0,
    ),
    AppNavDestination(
      route: '/settings/system-health',
      labelBuilder: _labelSystemHealth,
      icon: LucideIcons.activity,
      isVisible: _isVisibleSystemHealth,
      section: NavSection.management,
      mobilePriority: 0,
    ),

    // -------------------------------------------------------------------------
    // General Section
    // -------------------------------------------------------------------------
    AppNavDestination(
      route: '/notifications',
      labelBuilder: _labelNotifications,
      icon: LucideIcons.bell,
      isVisible: _isVisibleActive,
      section: NavSection.general,
      mobilePriority: 0,
    ),
    AppNavDestination(
      route: '/settings',
      labelBuilder: _labelSettings,
      icon: LucideIcons.settings,
      isVisible: _isVisibleAuthenticated,
      section: NavSection.general,
      mobilePriority: 40,
    ),
  ];

  // Visibility helpers
  static bool _isVisibleActive(StationAccessContext access) => access.isActive;
  static bool _isVisibleAuthenticated(StationAccessContext access) =>
      access.isAuthenticated;
  static bool _isVisibleSchedule(StationAccessContext access) =>
      access.canViewOwnSchedule || access.canManageSchedule;
  static bool _isVisibleHours(StationAccessContext access) =>
      access.canViewOwnHours;
  static bool _isVisibleAvailability(StationAccessContext access) =>
      access.canSubmitAvailability || access.canViewTeamAvailability;
  static bool _isVisibleAttendance(StationAccessContext access) =>
      access.canViewLiveAttendance || access.canViewEmployeeSelfAttendance;
  static bool _isVisibleReports(StationAccessContext access) =>
      access.canViewStationReports || access.canViewTeamReports;
  static bool _isVisibleExports(StationAccessContext access) =>
      access.canAccessExportCenter;
  static bool _isVisibleEmployees(StationAccessContext access) =>
      access.canManageEmployees;
  static bool _isVisibleShiftTemplates(StationAccessContext access) =>
      access.canManageShiftTemplates;
  static bool _isVisibleNfcTags(StationAccessContext access) =>
      access.canManageNfcTags;
  static bool _isVisibleAuditCenter(StationAccessContext access) =>
      access.canAccessAuditCenter;
  static bool _isVisibleSystemHealth(StationAccessContext access) =>
      access.canAccessSystemHealth;

  // Label helpers
  static String _labelDashboard(AppLocalizations l10n) => l10n.navDashboard;
  static String _labelSchedule(AppLocalizations l10n) => l10n.navSchedule;
  static String _labelHours(AppLocalizations l10n) => l10n.navMyHours;
  static String _labelAvailability(AppLocalizations l10n) =>
      l10n.navAvailability;
  static String _labelAttendance(AppLocalizations l10n) => l10n.navAttendance;
  static String _labelReports(AppLocalizations l10n) => l10n.navReports;
  static String _labelExports(AppLocalizations l10n) => l10n.navExports;
  static String _labelEmployees(AppLocalizations l10n) => l10n.navEmployees;
  static String _labelShiftTemplates(AppLocalizations l10n) =>
      l10n.navShiftTemplates;
  static String _labelNfcTags(AppLocalizations l10n) => l10n.settingsNfcTags;
  static String _labelAuditCenter(AppLocalizations l10n) => l10n.navAuditCenter;
  static String _labelSystemHealth(AppLocalizations l10n) =>
      l10n.navSystemHealth;
  static String _labelNotifications(AppLocalizations l10n) =>
      l10n.navNotifications;
  static String _labelSettings(AppLocalizations l10n) => l10n.navSettings;

  /// Returns all authorized destinations for this user/station context
  static List<AppNavDestination> getAuthorizedDestinations(
      StationAccessContext access) {
    return destinations.where((d) => d.isVisible(access)).toList();
  }

  /// Returns destinations grouped by section for expanded sidebars
  static Map<NavSection, List<AppNavDestination>> getGroupedDestinations(
      StationAccessContext access) {
    final authorized = getAuthorizedDestinations(access);
    final map = <NavSection, List<AppNavDestination>>{
      NavSection.workspace: [],
      NavSection.management: [],
      NavSection.general: [],
    };
    for (final d in authorized) {
      map[d.section]?.add(d);
    }
    return map;
  }

  /// Returns up to [maxItems] primary destinations for compact bottom navigation
  static List<AppNavDestination> getCompactBottomNavDestinations(
    StationAccessContext access, {
    int maxItems = 5,
  }) {
    final authorized = destinations
        .where((d) => d.isVisible(access) && d.mobilePriority > 0)
        .toList();

    // Sort by mobilePriority descending
    authorized.sort((a, b) => b.mobilePriority.compareTo(a.mobilePriority));

    if (authorized.length <= maxItems) {
      return authorized;
    }

    // Always ensure settings is included if available as the last item
    final top = authorized.take(maxItems - 1).toList();
    final settingsItem = authorized.firstWhere((d) => d.route == '/settings',
        orElse: () => top.last);
    if (!top.contains(settingsItem)) {
      top.add(settingsItem);
    } else if (authorized.length >= maxItems) {
      top.add(authorized[maxItems - 1]);
    }
    return top;
  }
}
