/// Sealed hierarchy of structured domain failures for YellowShifts.
abstract class AppFailure implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppFailure(this.message, {this.code, this.originalError});

  @override
  String toString() => '$runtimeType: $message (code: $code)';
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code, super.originalError});
}

class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure(
    super.message, {
    super.code = 'PERMISSION_DENIED',
    super.originalError,
  });
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message,
      {super.code = 'NOT_FOUND', super.originalError});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message,
      {super.code = 'NETWORK_ERROR', super.originalError});
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message,
      {super.code = 'DB_ERROR', super.originalError});
}

class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(super.message,
      {super.code = 'RATE_LIMITED', super.originalError});
}

class ScheduleConflictFailure extends AppFailure {
  const ScheduleConflictFailure(super.message,
      {super.code = 'SCHEDULE_CONFLICT', super.originalError});
}

class VersionConflictFailure extends AppFailure {
  const VersionConflictFailure(super.message,
      {super.code = 'VERSION_CONFLICT', super.originalError});
}

class StationDeactivatedFailure extends AppFailure {
  const StationDeactivatedFailure(super.message,
      {super.code = 'STATION_DEACTIVATED', super.originalError});
}

class MembershipDeactivatedFailure extends AppFailure {
  const MembershipDeactivatedFailure(super.message,
      {super.code = 'MEMBERSHIP_DEACTIVATED', super.originalError});
}

class NotPlatformAdminFailure extends AppFailure {
  const NotPlatformAdminFailure(super.message,
      {super.code = 'NOT_PLATFORM_ADMIN', super.originalError});
}

class StationCodeConflictFailure extends AppFailure {
  const StationCodeConflictFailure(super.message,
      {super.code = 'P00106', super.originalError});
}

class CannotRemoveLastStationAdminFailure extends AppFailure {
  const CannotRemoveLastStationAdminFailure(super.message,
      {super.code = 'P0001', super.originalError});
}

class StationAlreadyInactiveFailure extends AppFailure {
  const StationAlreadyInactiveFailure(super.message,
      {super.code = 'P00108', super.originalError});
}

class StationAlreadyActiveFailure extends AppFailure {
  const StationAlreadyActiveFailure(super.message,
      {super.code = 'P00109', super.originalError});
}

class StationProvisioningFailure extends AppFailure {
  const StationProvisioningFailure(super.message,
      {super.code = 'STATION_PROVISIONING_FAILED', super.originalError});
}

class StationAdminRoleForbiddenFailure extends AppFailure {
  const StationAdminRoleForbiddenFailure(super.message,
      {super.code = 'P00105', super.originalError});
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message,
      {super.code = 'TIMEOUT', super.originalError});
}

class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure(super.message,
      {super.code = 'SERVICE_UNAVAILABLE', super.originalError});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message,
      {super.code = 'UNKNOWN', super.originalError});
}
