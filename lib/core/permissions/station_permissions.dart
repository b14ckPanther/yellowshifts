import '../../features/stations/domain/station_membership.dart';
import 'station_access_context.dart';

/// Legacy adapter for StationPermissions.
/// Delegates to StationAccessContext to maintain backward compatibility
/// while enforcing strict station-scoped capability checks.
class StationPermissions {
  final StationRole role;
  final MembershipStatus status;
  final StationAccessContext? _context;

  const StationPermissions({
    required this.role,
    required this.status,
    StationAccessContext? context,
  }) : _context = context;

  factory StationPermissions.fromMembership(
    StationMembership? membership, {
    StationAccessContext? accessContext,
  }) {
    if (membership == null) {
      return const StationPermissions(
        role: StationRole.employee,
        status: MembershipStatus.inactive,
      );
    }
    return StationPermissions(
      role: membership.role,
      status: membership.status,
      context: accessContext,
    );
  }

  bool get isActive => status == MembershipStatus.active;

  // Administrative Capabilities (Strictly Admin only)
  bool get canManageStation =>
      _context?.canManageStationSettings ?? (isActive && role.isAdmin);
  bool get canManageMemberships =>
      _context?.canManageEmployees ?? (isActive && role.isAdmin);
  bool get canViewAuditLogs => isActive && role.isAdmin;

  // Operational Management Capabilities
  bool get canManageSchedules =>
      _context?.canManageSchedule ??
      (isActive && (role.isAdmin || role.isShiftManager));
  bool get canPublishSchedule =>
      _context?.canPublishSchedule ??
      (isActive && (role.isAdmin || role.isShiftManager));
  bool get canCorrectAttendance =>
      _context?.canCorrectAttendance ??
      (isActive && (role.isAdmin || role.isShiftManager));
  bool get canViewOperationalRoster =>
      _context?.canViewLiveAttendance ??
      (isActive && (role.isAdmin || role.isShiftManager));
  bool get canViewReports =>
      _context?.canViewStationReports ??
      (isActive && (role.isAdmin || role.isShiftManager));

  // Employee Operational Capabilities
  bool get canSubmitAvailability => _context?.canSubmitAvailability ?? isActive;
  bool get canClockInOut => _context?.canViewEmployeeSelfAttendance ?? isActive;
  bool get canViewOwnHistory => _context?.canViewOwnHours ?? isActive;
}
