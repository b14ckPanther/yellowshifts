import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import 'app_failure.dart';

/// Centralized Error Localizer for YellowShifts.
/// Translates raw PostgreSQL error codes (e.g. P0001, 42501, 23505),
/// Edge Function error codes, and domain failures into user-friendly localized messages.
class ErrorLocalizer {
  static String localize(dynamic error, AppLocalizations l10n) {
    if (error == null) return l10n.errorGeneric;

    String? code;
    String? message;

    if (error is AppFailure) {
      code = error.code;
      message = error.message;
    } else if (error is PostgrestException) {
      code = error.code;
      message = error.message;
    } else if (error is FunctionException) {
      code = error.status.toString();
      message = error.reasonPhrase;
      if (error.details is Map) {
        final det = error.details as Map;
        code = det['code']?.toString() ?? code;
        message = det['message']?.toString() ?? message;
      }
    } else if (error is Exception) {
      message = error.toString().replaceAll('Exception: ', '');
    } else {
      message = error.toString();
    }

    final lowerMsg = (message ?? '').toLowerCase();
    final cleanCode = (code ?? '').toUpperCase();

    // 1. Last active administrator protection
    if (cleanCode == 'P0001' ||
        cleanCode == 'LAST_ADMIN_REQUIRED' ||
        lowerMsg.contains('last active administrator') ||
        lowerMsg.contains('last active station manager') ||
        lowerMsg.contains('last admin')) {
      return l10n.errorLastAdminRequired;
    }

    if (cleanCode == 'P00105' ||
        cleanCode == 'STATION_ADMIN_ROLE_FORBIDDEN' ||
        lowerMsg.contains('cannot grant or revoke') ||
        lowerMsg.contains('only platform administrators may grant')) {
      return l10n.errorStationAdminRoleForbidden;
    }

    if (cleanCode == 'NOT_PLATFORM_ADMIN' ||
        lowerMsg.contains('platform administrator required')) {
      return l10n.errorNotPlatformAdmin;
    }

    if (cleanCode == 'P00106' ||
        cleanCode == 'STATION_CODE_CONFLICT' ||
        (cleanCode == '23505' && lowerMsg.contains('station code')) ||
        lowerMsg.contains('station code already exists')) {
      return l10n.errorStationCodeConflict;
    }

    if (cleanCode == 'P00108' ||
        cleanCode == 'STATION_ALREADY_INACTIVE' ||
        lowerMsg.contains('station is already inactive')) {
      return l10n.errorStationAlreadyInactive;
    }

    if (cleanCode == 'P00109' ||
        cleanCode == 'STATION_ALREADY_ACTIVE' ||
        lowerMsg.contains('station is already active')) {
      return l10n.errorStationAlreadyActive;
    }

    if (cleanCode == 'STATION_PROVISIONING_FAILED' ||
        lowerMsg.contains('station provisioning failed')) {
      return l10n.errorStationProvisioningFailed;
    }

    // 2. Permission denied / unauthorized
    if (cleanCode == '42501' ||
        cleanCode == 'PERMISSION_DENIED' ||
        cleanCode == 'FORBIDDEN' ||
        cleanCode == 'UNAUTHORIZED' ||
        lowerMsg.contains('access denied') ||
        lowerMsg.contains('permission denied')) {
      return l10n.errorPermissionDenied;
    }

    // 3. Duplicate phone number conflict
    if (cleanCode == '23505' && lowerMsg.contains('phone') ||
        cleanCode == 'DUPLICATE_PHONE' ||
        lowerMsg.contains('phone number is already associated') ||
        lowerMsg.contains('uq_profiles_phone')) {
      return l10n.errorDuplicatePhone;
    }

    // 4. Duplicate email conflict
    if (cleanCode == '23505' && lowerMsg.contains('email') ||
        cleanCode == 'EMAIL_EXISTS' ||
        cleanCode == 'DUPLICATE_EMAIL' ||
        lowerMsg.contains('email already') ||
        lowerMsg.contains('user already registered')) {
      return l10n.errorDuplicateEmail;
    }

    // 5. Generic uniqueness violation
    if (cleanCode == '23505') {
      return l10n.errorDuplicatePhone;
    }

    // 6. Invalid input / validation failure
    if (cleanCode == '22000' ||
        cleanCode == 'VALIDATION_ERROR' ||
        lowerMsg.contains('invalid phone number') ||
        lowerMsg.contains('between 1 and 100 characters') ||
        lowerMsg.contains('invalid input')) {
      return l10n.errorInvalidInput;
    }

    // 7. Not found
    if (cleanCode == 'P0002' ||
        cleanCode == 'NOT_FOUND' ||
        lowerMsg.contains('not found')) {
      return l10n.errorNotFound;
    }

    // 8. Phase 8: Export Expired (P0081)
    if (cleanCode == 'P0081' ||
        cleanCode == 'EXPORT_EXPIRED' ||
        lowerMsg.contains('export has expired') ||
        lowerMsg.contains('export link expired')) {
      return l10n.errorExportExpired;
    }

    // 9. Phase 8: Active Attendance Blocks Deactivation (P0082)
    if (cleanCode == 'P0082' ||
        cleanCode == 'ACTIVE_ATTENDANCE_BLOCKS_DEACTIVATION' ||
        lowerMsg.contains('active attendance') ||
        lowerMsg.contains('cannot deactivate station')) {
      return l10n.errorActiveAttendanceBlocksDeactivation;
    }

    // 10. Phase 9: Rate limiting (42901 / RATE_LIMITED)
    if (cleanCode == '42901' ||
        cleanCode == '429' ||
        cleanCode == 'RATE_LIMITED' ||
        lowerMsg.contains('too many requests') ||
        lowerMsg.contains('rate limit')) {
      return l10n.errorRateLimited;
    }

    // 11. Phase 9: Schedule & Version Conflicts
    if (cleanCode == 'SCHEDULE_CONFLICT' ||
        lowerMsg.contains('schedule conflict') ||
        lowerMsg.contains('already assigned')) {
      return l10n.errorScheduleConflict;
    }
    if (cleanCode == 'VERSION_CONFLICT' ||
        lowerMsg.contains('version conflict') ||
        lowerMsg.contains('optimistic lock')) {
      return l10n.errorVersionConflict;
    }

    // 12. Phase 9: Station & Membership Deactivation
    if (cleanCode == 'STATION_DEACTIVATED' ||
        lowerMsg.contains('station is inactive') ||
        lowerMsg.contains('station deactivated')) {
      return l10n.errorStationDeactivated;
    }
    if (cleanCode == 'MEMBERSHIP_DEACTIVATED' ||
        lowerMsg.contains('membership is inactive') ||
        lowerMsg.contains('membership suspended')) {
      return l10n.errorMembershipDeactivated;
    }

    // 13. Phase 9: Network & Timeout Errors
    if (cleanCode == 'TIMEOUT' ||
        lowerMsg.contains('timed out') ||
        lowerMsg.contains('deadline exceeded')) {
      return l10n.errorTimeout;
    }
    if (cleanCode == 'NETWORK_ERROR' ||
        cleanCode == 'OFFLINE_BLOCKED' ||
        lowerMsg.contains('offline') ||
        lowerMsg.contains('connection required')) {
      return l10n.errorOfflineActionBlocked;
    }
    if (cleanCode == 'SERVICE_UNAVAILABLE' ||
        cleanCode == '502' ||
        cleanCode == '503' ||
        lowerMsg.contains('failed host lookup') ||
        lowerMsg.contains('connection refused') ||
        lowerMsg.contains('service unavailable')) {
      return l10n.errorServiceUnavailable;
    }

    // Fallback: if message is meaningful and doesn't contain raw database stack traces
    if (message != null &&
        message.isNotEmpty &&
        !message.contains('PL/pgSQL') &&
        !message.contains('SQL statement') &&
        !message.contains('PostgrestException') &&
        !message.contains('FunctionException') &&
        !message.contains('minified:')) {
      return message;
    }

    return l10n.errorGeneric;
  }
}
