import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/permissions/station_permissions.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';

void main() {
  group('StationPermissions Calculation', () {
    final now = DateTime.now();

    test('Admin role has all operational and administrative capabilities', () {
      final membership = StationMembership(
        id: '1',
        stationId: 'st-1',
        userId: 'u-1',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final permissions = StationPermissions.fromMembership(membership);
      expect(permissions.canManageStation, true);
      expect(permissions.canManageMemberships, true);
      expect(permissions.canPublishSchedule, true);
      expect(permissions.canCorrectAttendance, true);
      expect(permissions.canViewOperationalRoster, true);
      expect(permissions.canSubmitAvailability, true);
      expect(permissions.canClockInOut, true);
    });

    test(
        'Shift Manager role has operational management but not administrative station management',
        () {
      final membership = StationMembership(
        id: '2',
        stationId: 'st-1',
        userId: 'u-2',
        role: StationRole.shiftManager,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final permissions = StationPermissions.fromMembership(membership);
      expect(permissions.canManageStation, false);
      expect(permissions.canManageMemberships, false);
      expect(permissions.canPublishSchedule, true);
      expect(permissions.canCorrectAttendance, true);
      expect(permissions.canViewOperationalRoster, true);
      expect(permissions.canSubmitAvailability, true);
      expect(permissions.canClockInOut, true);
    });

    test('Employee role has self operational capabilities only', () {
      final membership = StationMembership(
        id: '3',
        stationId: 'st-1',
        userId: 'u-3',
        role: StationRole.employee,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final permissions = StationPermissions.fromMembership(membership);
      expect(permissions.canManageStation, false);
      expect(permissions.canManageMemberships, false);
      expect(permissions.canPublishSchedule, false);
      expect(permissions.canCorrectAttendance, false);
      expect(permissions.canViewOperationalRoster, false);
      expect(permissions.canSubmitAvailability, true);
      expect(permissions.canClockInOut, true);
    });

    test('Inactive membership denies all operational capabilities', () {
      final membership = StationMembership(
        id: '4',
        stationId: 'st-1',
        userId: 'u-4',
        role: StationRole.admin,
        status: MembershipStatus.inactive,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final permissions = StationPermissions.fromMembership(membership);
      expect(permissions.canManageStation, false);
      expect(permissions.canManageMemberships, false);
      expect(permissions.canSubmitAvailability, false);
      expect(permissions.canClockInOut, false);
    });
  });

  group('StationAccessContext Phase 8 Capabilities', () {
    final now = DateTime.now();

    test('Admin has full Phase 8 operational & audit capabilities', () {
      final membership = StationMembership(
        id: '1',
        stationId: 'st-1',
        userId: 'u-1',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final context = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
        shiftManagerPermissions: null,
      );

      expect(context.canAccessExportCenter, true);
      expect(context.canExportStationReports, true);
      expect(context.canExportEmployeeDirectory, true);
      expect(context.canAccessAuditCenter, true);
      expect(context.canAccessSystemHealth, true);
      expect(context.canManageStationLifecycle, true);
    });

    test(
        'Shift Manager can export station reports but cannot access audit or health',
        () {
      final membership = StationMembership(
        id: '2',
        stationId: 'st-1',
        userId: 'u-2',
        role: StationRole.shiftManager,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final context = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
        shiftManagerPermissions: null,
      );

      expect(context.canAccessExportCenter, true);
      expect(context.canExportStationReports, true);
      expect(context.canExportEmployeeDirectory, false);
      expect(context.canAccessAuditCenter, false);
      expect(context.canAccessSystemHealth, false);
      expect(context.canManageStationLifecycle, false);
    });

    test(
        'Employee can only access export center for self hours and cannot access audit/health',
        () {
      final membership = StationMembership(
        id: '3',
        stationId: 'st-1',
        userId: 'u-3',
        role: StationRole.employee,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final context = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
        shiftManagerPermissions: null,
      );

      expect(context.canAccessExportCenter, true);
      expect(context.canExportStationReports, false);
      expect(context.canExportEmployeeDirectory, false);
      expect(context.canAccessAuditCenter, false);
      expect(context.canAccessSystemHealth, false);
      expect(context.canManageStationLifecycle, false);
    });

    test('Inactive user is denied all Phase 8 capabilities', () {
      final membership = StationMembership(
        id: '4',
        stationId: 'st-1',
        userId: 'u-4',
        role: StationRole.admin,
        status: MembershipStatus.inactive,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final context = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
        shiftManagerPermissions: null,
      );

      expect(context.canAccessExportCenter, false);
      expect(context.canExportStationReports, false);
      expect(context.canExportEmployeeDirectory, false);
      expect(context.canAccessAuditCenter, false);
      expect(context.canAccessSystemHealth, false);
      expect(context.canManageStationLifecycle, false);
    });
  });
}
