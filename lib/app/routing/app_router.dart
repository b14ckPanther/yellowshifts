import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state_provider.dart';
import '../../core/permissions/platform_admin_provider.dart';
import '../../core/permissions/station_access_context.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/availability/presentation/availability_screen.dart';
import '../../features/availability/presentation/employee_availability_screen.dart';
import '../../features/availability/presentation/manager_availability_screen.dart';
import '../../features/availability/presentation/availability_history_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/reports/presentation/screens/employee_my_hours_screen.dart';
import '../../features/reports/presentation/screens/manager_reports_screen.dart';
import '../../features/reports/presentation/screens/export_center_screen.dart';
import '../../features/audit/presentation/screens/audit_center_screen.dart';
import '../../features/system_health/presentation/screens/system_health_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/stations/presentation/station_selector_screen.dart';
import '../../features/settings/presentation/station_settings_screen.dart';
import '../../features/shift_templates/presentation/shift_templates_screen.dart';
import '../../features/settings/presentation/shift_manager_permissions_screen.dart';
import '../../features/attendance/presentation/manager_nfc_tags_screen.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';
import '../../features/notifications/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/dev_preview/presentation/design_system_preview_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_overview_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_stations_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_create_station_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_station_managers_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_audit_screen.dart';
import '../../features/platform_admin/presentation/screens/platform_health_screen.dart';
import '../../features/attendance/presentation/screens/nfc_attendance_verification_screen.dart';
import 'shell/adaptive_app_shell.dart';
import 'shell/platform_admin_shell.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateStreamProvider, (_, __) => notifyListeners());
    _ref.listen(currentAuthUserProvider, (_, __) => notifyListeners());
    _ref.listen(stationAccessContextProvider, (_, __) => notifyListeners());
    _ref.listen(isPlatformAdminProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authUser = _ref.read(currentAuthUserProvider);
    final access = _ref.read(stationAccessContextProvider);

    final loc = state.matchedLocation.isNotEmpty
        ? state.matchedLocation
        : state.uri.path;
    final path = state.uri.path;
    final isLoggingIn = loc == '/login' || path == '/login';
    final isDevPreview = loc.startsWith('/dev') || path.startsWith('/dev');
    final isPlatformPath =
        loc.startsWith('/platform') || path.startsWith('/platform');
    final isNfcRoute = loc.startsWith('/nfc/t/') || path.startsWith('/nfc/t/');
    final isPlatformAdmin = _ref.read(isPlatformAdminValueProvider);

    if (isDevPreview) return null;

    if (authUser == null) {
      if (isNfcRoute) {
        return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      return isLoggingIn ? null : '/login';
    }

    // Authenticated NFC route access: pass through directly
    if (isNfcRoute) return null;

    if (isPlatformPath) {
      return isPlatformAdmin
          ? null
          : (access.hasActiveStation ? '/dashboard' : '/station-select');
    }

    if (isLoggingIn) {
      final redirectParam = state.uri.queryParameters['redirect'];
      if (redirectParam != null &&
          redirectParam.isNotEmpty &&
          redirectParam.startsWith('/')) {
        return redirectParam;
      }
      if (isPlatformAdmin) return '/platform';
      return access.hasActiveStation ? '/dashboard' : '/station-select';
    }

    final isSelectingStation =
        loc == '/station-select' || path == '/station-select';
    if (!access.hasActiveStation && !isSelectingStation) {
      return isPlatformAdmin ? '/platform' : '/station-select';
    }

    // If station selected but membership is not active (fail-closed)
    if (access.hasActiveStation &&
        !access.isActive &&
        !isSelectingStation &&
        loc != '/settings' &&
        path != '/settings') {
      return '/station-select';
    }

    // -----------------------------------------------------------------------
    // Route Guards for Privileged Routes (Strictly Fail-Closed)
    // -----------------------------------------------------------------------
    if (path.startsWith('/employees') && !access.canManageEmployees) {
      return '/dashboard';
    }
    if (path == '/reports/exports' && !access.canAccessExportCenter) {
      return '/dashboard';
    }
    if (path == '/reports' &&
        !access.canViewStationReports &&
        !access.canViewTeamReports) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/audit') && !access.canAccessAuditCenter) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/system-health') &&
        !access.canAccessSystemHealth) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/station') &&
        !access.canManageStationSettings) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/shifts') &&
        !access.canManageShiftTemplates) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/permissions') &&
        !access.canManageShiftManagerPermissions) {
      return '/dashboard';
    }
    if (path.startsWith('/settings/nfc-tags') && !access.canManageNfcTags) {
      return '/dashboard';
    }
    if (path.startsWith('/availability/matrix') &&
        !access.canViewTeamAvailability) {
      return '/availability';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/nfc/t/:token',
        builder: (context, state) => NfcAttendanceVerificationScreen(
          token: state.pathParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/station-select',
        builder: (context, state) => const StationSelectorScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => PlatformAdminShell(child: child),
        routes: [
          GoRoute(
            path: '/platform',
            builder: (context, state) => const PlatformOverviewScreen(),
          ),
          GoRoute(
            path: '/platform/stations',
            builder: (context, state) => const PlatformStationsScreen(),
          ),
          GoRoute(
            path: '/platform/stations/new',
            builder: (context, state) => const PlatformCreateStationScreen(),
          ),
          GoRoute(
            path: '/platform/stations/:stationId/managers',
            builder: (context, state) => PlatformStationManagersScreen(
              stationId: state.pathParameters['stationId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/platform/audit',
            builder: (context, state) => const PlatformAuditScreen(),
          ),
          GoRoute(
            path: '/platform/health',
            builder: (context, state) => const PlatformHealthScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdaptiveAppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/availability',
            builder: (context, state) => const AvailabilityScreen(),
          ),
          GoRoute(
            path: '/availability/matrix',
            builder: (context, state) => const ManagerAvailabilityScreen(),
          ),
          GoRoute(
            path: '/availability/submit',
            builder: (context, state) => const EmployeeAvailabilityScreen(),
          ),
          GoRoute(
            path: '/availability/history',
            builder: (context, state) => const AvailabilityHistoryScreen(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/hours',
            builder: (context, state) => const EmployeeMyHoursScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ManagerReportsScreen(),
          ),
          GoRoute(
            path: '/reports/exports',
            builder: (context, state) => const ExportCenterScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/station',
            builder: (context, state) => const StationSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/audit',
            builder: (context, state) => const AuditCenterScreen(),
          ),
          GoRoute(
            path: '/settings/system-health',
            builder: (context, state) => const SystemHealthScreen(),
          ),
          GoRoute(
            path: '/settings/nfc-tags',
            builder: (context, state) => const ManagerNfcTagsScreen(),
          ),
          GoRoute(
            path: '/settings/shifts',
            builder: (context, state) => const ShiftTemplatesScreen(),
          ),
          GoRoute(
            path: '/settings/permissions',
            builder: (context, state) => const ShiftManagerPermissionsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
          GoRoute(
            path: '/dev/design-system',
            builder: (context, state) => const DesignSystemPreviewScreen(),
          ),
        ],
      ),
    ],
  );
});
