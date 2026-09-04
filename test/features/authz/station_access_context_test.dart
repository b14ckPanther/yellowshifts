import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/features/permissions/domain/shift_manager_permissions.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';

void main() {
  group('StationAccessContext - Fail-Closed & Role Isolation', () {
    test('Unauthenticated context grants ZERO capabilities', () {
      final ctx = StationAccessContext.unauthenticated();

      expect(ctx.isAuthenticated, isFalse);
      expect(ctx.hasActiveStation, isFalse);
      expect(ctx.isActive, isFalse);
      expect(ctx.activeRole, isNull);
      expect(ctx.isEmployee, isFalse);
      expect(ctx.isShiftManager, isFalse);
      expect(ctx.isAdmin, isFalse);

      // Self-service
      expect(ctx.canViewEmployeeSelfAttendance, isFalse);
      expect(ctx.canViewOwnHours, isFalse);
      expect(ctx.canSubmitAvailability, isFalse);
      expect(ctx.canViewOwnSchedule, isFalse);

      // Operational
      expect(ctx.canViewLiveAttendance, isFalse);
      expect(ctx.canViewTeamReports, isFalse);
      expect(ctx.canViewStationReports, isFalse);
      expect(ctx.canManageSchedule, isFalse);
      expect(ctx.canPublishSchedule, isFalse);
      expect(ctx.canCorrectAttendance, isFalse);

      // Administrative
      expect(ctx.canManageEmployees, isFalse);
      expect(ctx.canCreateEmployees, isFalse);
      expect(ctx.canEditEmployeeProfiles, isFalse);
      expect(ctx.canManageMembershipRoles, isFalse);
      expect(ctx.canManageStationSettings, isFalse);
      expect(ctx.canManageNfcTags, isFalse);
    });

    test('Inactive membership in active station grants ZERO capabilities', () {
      final membership = StationMembership(
        id: 'mem-1',
        stationId: 'st-1',
        userId: 'u-1',
        role: StationRole.admin,
        status: MembershipStatus.inactive,
        joinedAt: DateTime.now(),
      );

      final ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
      );

      expect(ctx.isActive, isFalse);
      expect(ctx.activeRole, isNull);
      expect(ctx.isAdmin, isFalse);
      expect(ctx.canManageEmployees, isFalse);
      expect(ctx.canViewOwnHours, isFalse);
      expect(ctx.canManageStationSettings, isFalse);
    });

    test('Active EMPLOYEE context grants ONLY self-service capabilities', () {
      final membership = StationMembership(
        id: 'mem-emp',
        stationId: 'st-1',
        userId: 'u-emp',
        role: StationRole.employee,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
      );

      final ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
      );

      expect(ctx.isActive, isTrue);
      expect(ctx.activeRole, StationRole.employee);
      expect(ctx.isEmployee, isTrue);
      expect(ctx.isShiftManager, isFalse);
      expect(ctx.isAdmin, isFalse);

      // Allowed self-service
      expect(ctx.canViewEmployeeSelfAttendance, isTrue);
      expect(ctx.canViewOwnHours, isTrue);
      expect(ctx.canSubmitAvailability, isTrue);
      expect(ctx.canViewOwnSchedule, isTrue);

      // Strictly denied management
      expect(ctx.canManageEmployees, isFalse);
      expect(ctx.canCreateEmployees, isFalse);
      expect(ctx.canEditEmployeeProfiles, isFalse);
      expect(ctx.canManageMembershipRoles, isFalse);
      expect(ctx.canManageMembershipStatuses, isFalse);
      expect(ctx.canResetEmployeePassword, isFalse);
      expect(ctx.canRevokeEmployeeSessions, isFalse);
      expect(ctx.canManageStationSettings, isFalse);
      expect(ctx.canManageShiftManagerPermissions, isFalse);
      expect(ctx.canManageNfcTags, isFalse);
      expect(ctx.canManageShiftTemplates, isFalse);
      expect(ctx.canManageSchedule, isFalse);
      expect(ctx.canPublishSchedule, isFalse);
      expect(ctx.canViewStationReports, isFalse);
      expect(ctx.canViewTeamReports, isFalse);
      expect(ctx.canCorrectAttendance, isFalse);
    });

    test('Active SHIFT_MANAGER context respects delegated permissions', () {
      final membership = StationMembership(
        id: 'mem-mgr',
        stationId: 'st-1',
        userId: 'u-mgr',
        role: StationRole.shiftManager,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
      );

      const permissions = ShiftManagerPermissions(
        shiftTemplatesManage: true,
        scheduleManage: true,
        schedulePublish: false,
        attendanceCorrect: true,
        reportsTeamRead: true,
        reportsStationRead: false,
        availabilityTeamRead: true,
      );

      final ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
        shiftManagerPermissions: permissions,
      );

      expect(ctx.isActive, isTrue);
      expect(ctx.isShiftManager, isTrue);
      expect(ctx.isAdmin, isFalse);
      expect(ctx.isEmployee, isFalse);

      // Delegated permissions
      expect(ctx.canManageShiftTemplates, isTrue);
      expect(ctx.canManageSchedule, isTrue);
      expect(ctx.canPublishSchedule, isFalse);
      expect(ctx.canCorrectAttendance, isTrue);
      expect(ctx.canViewTeamReports, isTrue);
      expect(ctx.canViewStationReports, isFalse);
      expect(ctx.canViewLiveAttendance, isTrue);

      // Strictly denied administrative operations
      expect(ctx.canManageEmployees, isFalse);
      expect(ctx.canCreateEmployees, isFalse);
      expect(ctx.canEditEmployeeProfiles, isFalse);
      expect(ctx.canManageMembershipRoles, isFalse);
      expect(ctx.canManageStationSettings, isFalse);
      expect(ctx.canManageNfcTags, isFalse);
    });

    test(
        'Platform Admin operating a station gets station-admin capabilities without membership',
        () {
      const ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        isPlatformAdmin: true,
        operatingStationId: 'st-1',
      );

      expect(ctx.isOperatingAsPlatformAdmin, isTrue);
      expect(ctx.isActive, isTrue);
      expect(ctx.isAdmin, isTrue);
      expect(ctx.isEmployee, isFalse);
      expect(ctx.isShiftManager, isFalse);
      expect(ctx.canAssignStationAdmin, isTrue);
      expect(ctx.canAccessPlatformAdministration, isTrue);
      expect(ctx.canManageEmployees, isTrue);
      expect(ctx.canManageStationSettings, isTrue);
      expect(ctx.canManageSchedule, isTrue);
    });

    test('Platform Admin without operating context is not a station admin', () {
      const ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: false,
        isPlatformAdmin: true,
      );

      expect(ctx.isOperatingAsPlatformAdmin, isFalse);
      expect(ctx.isAdmin, isFalse);
      expect(ctx.canAccessPlatformAdministration, isTrue);
      expect(ctx.canAssignStationAdmin, isTrue);
      expect(ctx.canManageEmployees, isFalse);
    });

    test('Station ADMIN cannot assign Station Admin', () {
      final membership = StationMembership(
        id: 'mem-adm',
        stationId: 'st-1',
        userId: 'u-adm',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
      );

      final ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
      );

      expect(ctx.isAdmin, isTrue);
      expect(ctx.canManageMembershipRoles, isTrue);
      expect(ctx.canAssignStationAdmin, isFalse);
      expect(ctx.canAccessPlatformAdministration, isFalse);
    });

    test('Active ADMIN context grants ALL station capabilities', () {
      final membership = StationMembership(
        id: 'mem-adm',
        stationId: 'st-1',
        userId: 'u-adm',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
      );

      final ctx = StationAccessContext(
        isAuthenticated: true,
        hasActiveStation: true,
        activeStationId: 'st-1',
        activeMembership: membership,
      );

      expect(ctx.isActive, isTrue);
      expect(ctx.isAdmin, isTrue);
      expect(ctx.isShiftManager, isFalse);
      expect(ctx.isEmployee, isFalse);

      // Operational
      expect(ctx.canManageShiftTemplates, isTrue);
      expect(ctx.canManageSchedule, isTrue);
      expect(ctx.canPublishSchedule, isTrue);
      expect(ctx.canCorrectAttendance, isTrue);
      expect(ctx.canViewStationReports, isTrue);
      expect(ctx.canViewTeamReports, isTrue);
      expect(ctx.canViewLiveAttendance, isTrue);

      // Administrative
      expect(ctx.canManageEmployees, isTrue);
      expect(ctx.canCreateEmployees, isTrue);
      expect(ctx.canEditEmployeeProfiles, isTrue);
      expect(ctx.canManageMembershipRoles, isTrue);
      expect(ctx.canManageMembershipStatuses, isTrue);
      expect(ctx.canResetEmployeePassword, isTrue);
      expect(ctx.canRevokeEmployeeSessions, isTrue);
      expect(ctx.canManageStationSettings, isTrue);
      expect(ctx.canManageShiftManagerPermissions, isTrue);
      expect(ctx.canManageNfcTags, isTrue);
    });
  });
}
