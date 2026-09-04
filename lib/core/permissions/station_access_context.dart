import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/permissions/domain/shift_manager_permissions.dart';
import '../../features/permissions/presentation/shift_manager_permissions_provider.dart';
import '../../features/stations/domain/station_membership.dart';
import '../../features/stations/presentation/active_station_provider.dart';
import '../auth/auth_state_provider.dart';
import 'platform_admin_provider.dart';

/// Single authoritative station-scoped capability context.
/// Ensures all UI visibility, route guards, action controls, and repository
/// authorization evaluate strictly through the active station membership.
///
/// DEFAULT IS STRICTLY FAIL-CLOSED:
/// Unknown, loading, null, inactive, or suspended memberships grant ZERO privileged capabilities.
class StationAccessContext {
  final bool isAuthenticated;
  final bool hasActiveStation;
  final String? activeStationId;
  final StationMembership? activeMembership;
  final ShiftManagerPermissions? shiftManagerPermissions;
  final bool isPlatformAdmin;
  final String? operatingStationId;

  const StationAccessContext({
    required this.isAuthenticated,
    required this.hasActiveStation,
    this.activeStationId,
    this.activeMembership,
    this.shiftManagerPermissions,
    this.isPlatformAdmin = false,
    this.operatingStationId,
  });

  /// Factory for an unauthenticated or loading context (FAIL-CLOSED)
  factory StationAccessContext.unauthenticated() {
    return const StationAccessContext(
      isAuthenticated: false,
      hasActiveStation: false,
    );
  }

  /// Whether the membership in the current active station is strictly ACTIVE
  /// and the station itself is active — or a Platform Admin is explicitly
  /// operating this station without a membership row.
  bool get isOperatingAsPlatformAdmin =>
      isAuthenticated &&
      isPlatformAdmin &&
      hasActiveStation &&
      operatingStationId != null &&
      operatingStationId == activeStationId;

  bool get isActive =>
      isOperatingAsPlatformAdmin ||
      (isAuthenticated &&
          hasActiveStation &&
          activeMembership != null &&
          activeMembership!.status == MembershipStatus.active &&
          (activeMembership!.station == null ||
              activeMembership!.station!.isActive));

  /// The active role for the current station (null if not active member)
  StationRole? get activeRole => isActive ? activeMembership?.role : null;

  // Role Identifiers (Strictly station-scoped & active-membership gated)
  bool get isEmployee =>
      isActive &&
      !isOperatingAsPlatformAdmin &&
      activeRole == StationRole.employee;
  bool get isShiftManager =>
      isActive &&
      !isOperatingAsPlatformAdmin &&
      activeRole == StationRole.shiftManager;
  bool get isAdmin =>
      isOperatingAsPlatformAdmin ||
      (isActive && activeRole == StationRole.admin);

  /// Station-admin employee screens may not grant or revoke ADMIN.
  bool get canAssignStationAdmin => isPlatformAdmin;
  bool get canAccessPlatformAdministration => isPlatformAdmin;

  // --------------------------------------------------------------------------
  // Employee Self-Service Capabilities (available to all ACTIVE station members)
  // --------------------------------------------------------------------------
  bool get canViewEmployeeSelfAttendance => isActive;
  bool get canViewOwnHours => isActive;
  bool get canSubmitAvailability => isActive;
  bool get canViewOwnSchedule => isActive;

  // --------------------------------------------------------------------------
  // Operational Capabilities (Admin: always true; Shift Manager: delegated/configured; Employee: always false)
  // --------------------------------------------------------------------------
  bool get canViewTeamAvailability =>
      isAdmin ||
      (isShiftManager &&
          (shiftManagerPermissions?.availabilityTeamRead ?? true));

  bool get canManageShiftTemplates =>
      isAdmin ||
      (isShiftManager &&
          (shiftManagerPermissions?.shiftTemplatesManage ?? false));

  bool get canManageAvailabilityPeriods =>
      isAdmin ||
      (isShiftManager &&
          ((shiftManagerPermissions?.availabilityPeriodCreate ?? false) ||
              (shiftManagerPermissions?.availabilityPeriodOpen ?? false) ||
              (shiftManagerPermissions?.availabilityPeriodClose ?? false)));

  bool get canManageSchedule =>
      isAdmin ||
      (isShiftManager && (shiftManagerPermissions?.scheduleManage ?? false));

  bool get canPublishSchedule =>
      isAdmin ||
      (isShiftManager && (shiftManagerPermissions?.schedulePublish ?? false));

  bool get canViewLiveAttendance => isAdmin || isShiftManager;

  bool get canCorrectAttendance =>
      isAdmin ||
      (isShiftManager && (shiftManagerPermissions?.attendanceCorrect ?? false));

  bool get canViewTeamReports =>
      isAdmin ||
      (isShiftManager && (shiftManagerPermissions?.reportsTeamRead ?? true));

  bool get canViewStationReports =>
      isAdmin ||
      (isShiftManager && (shiftManagerPermissions?.reportsStationRead ?? true));

  // --------------------------------------------------------------------------
  // Phase 8: Operational Exports & Audit Capabilities
  // --------------------------------------------------------------------------
  bool get canAccessExportCenter =>
      isActive &&
      (isAdmin ||
          canViewStationReports ||
          canViewTeamReports ||
          canViewOwnHours);

  bool get canExportStationReports =>
      isAdmin ||
      (isShiftManager &&
          ((shiftManagerPermissions?.reportsStationRead ?? true) ||
              (shiftManagerPermissions?.reportsTeamRead ?? true)));

  bool get canExportEmployeeDirectory => isAdmin;
  bool get canAccessAuditCenter => isAdmin;
  bool get canAccessSystemHealth => isAdmin;
  bool get canManageStationLifecycle => isAdmin;

  // --------------------------------------------------------------------------
  // Administrative Capabilities (STRICTLY Admin Only!)
  // --------------------------------------------------------------------------
  bool get canManageEmployees => isAdmin;
  bool get canCreateEmployees => isAdmin;
  bool get canEditEmployeeProfiles => isAdmin;
  bool get canManageMembershipRoles => isAdmin;
  bool get canManageMembershipStatuses => isAdmin;
  bool get canResetEmployeePassword => isAdmin;
  bool get canRevokeEmployeeSessions => isAdmin;
  bool get canManageNfcTags => isAdmin;
  bool get canManageStationSettings => isAdmin;
  bool get canManageShiftManagerPermissions => isAdmin;
}

/// Central Riverpod Provider for StationAccessContext.
/// Re-evaluates immediately on:
/// - Auth sign-in / sign-out (`currentAuthUserProvider`)
/// - Station switch (`activeStationIdProvider`)
/// - Membership updates / realtime status change (`activeMembershipProvider`)
/// - Shift Manager permissions updates (`shiftManagerPermissionsProvider`)
final stationAccessContextProvider = Provider<StationAccessContext>((ref) {
  final authUser = ref.watch(currentAuthUserProvider);
  if (authUser == null) {
    return StationAccessContext.unauthenticated();
  }

  final isPlatformAdmin = ref.watch(isPlatformAdminValueProvider);
  final operatingStationId = ref.watch(platformOperatingStationIdProvider);
  final activeStationId = ref.watch(activeStationIdProvider);
  if (activeStationId == null) {
    return StationAccessContext(
      isAuthenticated: true,
      hasActiveStation: false,
      isPlatformAdmin: isPlatformAdmin,
      operatingStationId: operatingStationId,
    );
  }

  final activeMembership = ref.watch(activeMembershipProvider);
  final shiftManagerPermissionsAsync =
      ref.watch(shiftManagerPermissionsProvider);

  return StationAccessContext(
    isAuthenticated: true,
    hasActiveStation: true,
    activeStationId: activeStationId,
    activeMembership: activeMembership,
    shiftManagerPermissions: shiftManagerPermissionsAsync.value,
    isPlatformAdmin: isPlatformAdmin,
    operatingStationId: operatingStationId,
  );
});
