import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/platform_audit_entry.dart';
import '../domain/platform_overview.dart';
import '../domain/platform_station_manager.dart';
import '../domain/platform_station_summary.dart';
import '../domain/station_create_result.dart';

abstract class PlatformAdminRepository {
  Future<bool> isPlatformAdmin();
  Future<PlatformOverview> getOverview();
  Future<List<PlatformStationSummary>> listStations();
  Future<StationCreateResult> createStation({
    required String name,
    required String code,
    String timezone,
    String locale,
    int weekStart,
    String? idempotencyKey,
    String? initialAdminUserId,
    String? initialAdminEmail,
    String? initialAdminFirstName,
    String? initialAdminLastName,
    String? initialAdminPhone,
  });
  Future<void> updateStation({
    required String stationId,
    required String name,
    required String code,
    required String timezone,
    String locale,
    int weekStart,
  });
  Future<void> setStationActive({
    required String stationId,
    required bool isActive,
    required String reason,
    bool forceDeactivate,
  });
  Future<List<PlatformStationManager>> getStationManagers(String stationId);
  Future<StationManagerAssignmentResult> assignStationAdmin({
    required String stationId,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? replaceUserId,
    String? reason,
  });
  Future<void> removeStationAdmin({
    required String stationId,
    required String userId,
    required String reason,
    String demoteTo,
    bool deactivate,
  });
  Future<void> updateStationManager({
    required String stationId,
    required String userId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? employeeCode,
  });
  Future<String> resetManagerPassword({
    required String stationId,
    required String userId,
    String? newPassword,
  });
  Future<PlatformAuditPage> queryAuditLogs({
    String? stationId,
    String? action,
    String? actorId,
    DateTime? from,
    DateTime? to,
    int limit,
    int offset,
  });
}

class SupabasePlatformAdminRepository implements PlatformAdminRepository {
  final SupabaseClient _client;

  SupabasePlatformAdminRepository(this._client);

  Never _throwMapped(Object e) {
    if (e is AppFailure) throw e;
    String? code;
    String message = e.toString();
    if (e is FunctionException) {
      code = e.status.toString();
      if (e.details is Map) {
        final det = e.details as Map;
        code = det['code']?.toString() ?? code;
        message = det['message']?.toString() ?? message;
      }
    } else if (e is PostgrestException) {
      code = e.code;
      message = e.message;
    }
    final upper = (code ?? '').toUpperCase();
    final lower = message.toLowerCase();
    if (upper == 'NOT_PLATFORM_ADMIN' ||
        lower.contains('platform administrator required')) {
      throw NotPlatformAdminFailure(message, code: upper, originalError: e);
    }
    if (upper == 'P00106' || lower.contains('station code already exists')) {
      throw StationCodeConflictFailure(message, originalError: e);
    }
    if (upper == 'P0001') {
      throw CannotRemoveLastStationAdminFailure(message, originalError: e);
    }
    if (upper == 'P00108') {
      throw StationAlreadyInactiveFailure(message, originalError: e);
    }
    if (upper == 'P00109') {
      throw StationAlreadyActiveFailure(message, originalError: e);
    }
    if (upper == 'P00105') {
      throw StationAdminRoleForbiddenFailure(message, originalError: e);
    }
    if (upper == 'STATION_PROVISIONING_FAILED') {
      throw StationProvisioningFailure(message, originalError: e);
    }
    if (e is PostgrestException) {
      throw DatabaseFailure(message, code: code, originalError: e);
    }
    throw UnknownFailure(message, originalError: e);
  }

  @override
  Future<bool> isPlatformAdmin() async {
    try {
      final result = await _client.rpc('is_platform_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PlatformOverview> getOverview() async {
    try {
      final res = await _client.rpc('platform_get_overview');
      return PlatformOverview.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<List<PlatformStationSummary>> listStations() async {
    try {
      final res = await _client.rpc('platform_list_stations');
      final list = res is List ? res : const [];
      return list
          .whereType<Map>()
          .map((row) =>
              PlatformStationSummary.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<StationCreateResult> createStation({
    required String name,
    required String code,
    String timezone = 'Asia/Jerusalem',
    String locale = 'he',
    int weekStart = 0,
    String? idempotencyKey,
    String? initialAdminUserId,
    String? initialAdminEmail,
    String? initialAdminFirstName,
    String? initialAdminLastName,
    String? initialAdminPhone,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'platform-create-station',
        body: {
          'name': name,
          'code': code,
          'timezone': timezone,
          'locale': locale,
          'week_start': weekStart,
          'idempotency_key': idempotencyKey,
          'initial_admin_user_id': initialAdminUserId,
          'initial_admin_email': initialAdminEmail,
          'initial_admin_first_name': initialAdminFirstName,
          'initial_admin_last_name': initialAdminLastName,
          'initial_admin_phone': initialAdminPhone,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        final err = data['error'];
        final codeStr = err is Map ? err['code']?.toString() : null;
        final msg = err is Map ? err['message']?.toString() : data.toString();
        _throwMapped(PostgrestException(message: msg ?? '', code: codeStr));
      }
      return StationCreateResult.fromJson(
          Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> updateStation({
    required String stationId,
    required String name,
    required String code,
    required String timezone,
    String locale = 'he',
    int weekStart = 0,
  }) async {
    try {
      await _client.rpc('platform_update_station', params: {
        'p_station_id': stationId,
        'p_name': name,
        'p_code': code,
        'p_timezone': timezone,
        'p_locale': locale,
        'p_week_start': weekStart,
      });
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> setStationActive({
    required String stationId,
    required bool isActive,
    required String reason,
    bool forceDeactivate = false,
  }) async {
    try {
      await _client.rpc('platform_set_station_active', params: {
        'p_station_id': stationId,
        'p_is_active': isActive,
        'p_reason': reason,
        'p_force_deactivate': forceDeactivate,
      });
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<List<PlatformStationManager>> getStationManagers(
      String stationId) async {
    try {
      final res = await _client.rpc('platform_get_station_managers', params: {
        'p_station_id': stationId,
      });
      final list = res is List ? res : const [];
      return list
          .whereType<Map>()
          .map((row) =>
              PlatformStationManager.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<StationManagerAssignmentResult> assignStationAdmin({
    required String stationId,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? replaceUserId,
    String? reason,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'platform-assign-station-admin',
        body: {
          'station_id': stationId,
          'user_id': userId,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'replace_user_id': replaceUserId,
          'reason': reason,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        final err = data['error'];
        final codeStr = err is Map ? err['code']?.toString() : null;
        final msg = err is Map ? err['message']?.toString() : data.toString();
        _throwMapped(PostgrestException(message: msg ?? '', code: codeStr));
      }
      return StationManagerAssignmentResult.fromJson(
          Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> removeStationAdmin({
    required String stationId,
    required String userId,
    required String reason,
    String demoteTo = 'EMPLOYEE',
    bool deactivate = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'platform-remove-station-admin',
        body: {
          'station_id': stationId,
          'user_id': userId,
          'reason': reason,
          'demote_to': demoteTo,
          'deactivate': deactivate,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        final err = data['error'];
        final codeStr = err is Map ? err['code']?.toString() : null;
        final msg = err is Map ? err['message']?.toString() : data.toString();
        _throwMapped(PostgrestException(message: msg ?? '', code: codeStr));
      }
    } catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> updateStationManager({
    required String stationId,
    required String userId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? employeeCode,
  }) async {
    // 1. Attempt direct platform_update_station_manager RPC
    try {
      await _client.rpc('platform_update_station_manager', params: {
        'p_station_id': stationId,
        'p_target_user_id': userId,
        'p_first_name': firstName.trim(),
        'p_last_name': lastName.trim(),
        'p_email': email?.trim(),
        'p_phone':
            phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
        'p_employee_code':
            employeeCode != null && employeeCode.trim().isNotEmpty
                ? employeeCode.trim()
                : null,
      });
      return;
    } catch (rpcErr) {
      // 2. Fallback to admin-update-employee edge function if RPC not deployed yet
      try {
        final response = await _client.functions.invoke(
          'admin-update-employee',
          body: {
            'station_id': stationId,
            'user_id': userId,
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email?.trim(),
            'phone': phone?.trim(),
            'employee_code': employeeCode?.trim(),
          },
        );
        final data = response.data;
        if (data is Map && data['error'] != null) {
          final err = data['error'];
          final codeStr = err is Map ? err['code']?.toString() : null;
          final msg = err is Map ? err['message']?.toString() : data.toString();
          _throwMapped(PostgrestException(message: msg ?? '', code: codeStr));
        }
      } catch (e) {
        _throwMapped(e);
      }
    }
  }

  @override
  Future<String> resetManagerPassword({
    required String stationId,
    required String userId,
    String? newPassword,
  }) async {
    final passwordToSet = newPassword?.trim();
    final effectivePassword = (passwordToSet != null &&
            passwordToSet.isNotEmpty)
        ? passwordToSet
        : 'Ys#${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}!A1';

    try {
      final rpcRes = await _client.rpc(
        'admin_set_user_password',
        params: {
          'p_station_id': stationId,
          'p_target_user_id': userId,
          'p_new_password': effectivePassword,
        },
      );
      if (rpcRes is Map && rpcRes['temporary_password'] != null) {
        return rpcRes['temporary_password'] as String;
      }
      return effectivePassword;
    } catch (rpcErr) {
      try {
        final response = await _client.functions.invoke(
          'admin-reset-password',
          body: {
            'station_id': stationId,
            'user_id': userId,
            'new_password': effectivePassword,
          },
        );
        final data = response.data;
        if (data is Map && data['temporary_password'] != null) {
          return data['temporary_password'] as String;
        }
        return effectivePassword;
      } catch (e) {
        _throwMapped(e);
      }
    }
  }

  @override
  Future<PlatformAuditPage> queryAuditLogs({
    String? stationId,
    String? action,
    String? actorId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _client.rpc('platform_query_audit_logs', params: {
        'p_station_id': stationId,
        'p_action': action,
        'p_actor_id': actorId,
        if (from != null) 'p_from': from.toIso8601String(),
        if (to != null) 'p_to': to.toIso8601String(),
        'p_limit': limit,
        'p_offset': offset,
      });
      return PlatformAuditPage.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      _throwMapped(e);
    }
  }
}

final platformAdminRepositoryProvider =
    Provider<PlatformAdminRepository>((ref) {
  return SupabasePlatformAdminRepository(ref.watch(supabaseClientProvider));
});
