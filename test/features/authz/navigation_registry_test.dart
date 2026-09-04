import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/app/routing/navigation_registry.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';

void main() {
  group('AppNavigationRegistry - Dynamic Role Filtering', () {
    test('EMPLOYEE gets strictly employee-scoped navigation destinations', () {
      final employeeAccess = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: StationMembership(
          id: 'mem-1',
          stationId: 'st-1',
          userId: 'u-1',
          role: StationRole.employee,
          status: MembershipStatus.active,
          joinedAt: DateTime.now(),
        ),
      );

      final authorized =
          AppNavigationRegistry.getAuthorizedDestinations(employeeAccess);
      final routes = authorized.map((d) => d.route).toList();

      // Allowed
      expect(routes, contains('/dashboard'));
      expect(routes, contains('/schedule'));
      expect(routes, contains('/hours'));
      expect(routes, contains('/availability'));
      expect(routes, contains('/attendance'));
      expect(routes, contains('/notifications'));
      expect(routes, contains('/settings'));

      // Strictly Blocked
      expect(routes, isNot(contains('/employees')));
      expect(routes, isNot(contains('/reports')));
      expect(routes, isNot(contains('/settings/shifts')));
      expect(routes, isNot(contains('/settings/nfc-tags')));

      // Compact bottom bar should never include /employees
      final bottomNav =
          AppNavigationRegistry.getCompactBottomNavDestinations(employeeAccess);
      final bottomRoutes = bottomNav.map((d) => d.route).toList();
      expect(bottomRoutes, isNot(contains('/employees')));
      expect(bottomRoutes, isNot(contains('/reports')));
      expect(bottomRoutes.length, lessThanOrEqualTo(5));
    });

    test('ADMIN gets full navigation including management section', () {
      final adminAccess = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: StationMembership(
          id: 'mem-adm',
          stationId: 'st-1',
          userId: 'u-adm',
          role: StationRole.admin,
          status: MembershipStatus.active,
          joinedAt: DateTime.now(),
        ),
      );

      final authorized =
          AppNavigationRegistry.getAuthorizedDestinations(adminAccess);
      final routes = authorized.map((d) => d.route).toList();

      expect(routes, contains('/dashboard'));
      expect(routes, contains('/schedule'));
      expect(routes, contains('/hours'));
      expect(routes, contains('/availability'));
      expect(routes, contains('/attendance'));
      expect(routes, contains('/reports'));
      expect(routes, contains('/employees'));
      expect(routes, contains('/settings/shifts'));
      expect(routes, contains('/settings/nfc-tags'));
      expect(routes, contains('/notifications'));
      expect(routes, contains('/settings'));

      final grouped = AppNavigationRegistry.getGroupedDestinations(adminAccess);
      expect(grouped[NavSection.workspace], isNotEmpty);
      expect(grouped[NavSection.management], isNotEmpty);
      expect(grouped[NavSection.general], isNotEmpty);
    });

    test('UNAUTHENTICATED context returns ONLY settings if authenticated', () {
      final unauthAccess = StationAccessContext.unauthenticated();

      final authorized =
          AppNavigationRegistry.getAuthorizedDestinations(unauthAccess);
      expect(authorized, isEmpty);
    });
  });
}
