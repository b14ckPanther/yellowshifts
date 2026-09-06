import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../stations/domain/station_membership.dart';
import '../domain/employee_details.dart';

abstract class EmployeeRepository {
  Future<List<EmployeeDetails>> getStationEmployees({
    required String stationId,
    String? search,
    StationRole? role,
    MembershipStatus? status,
  });

  Future<Map<String, dynamic>> createEmployee({
    required String stationId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required StationRole role,
    String? employeeCode,
  });

  Future<Map<String, dynamic>> updateEmployeeProfile({
    required String stationId,
    required String userId,
    required String membershipId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? preferredLocale,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  });

  Future<void> updateMembership({
    required String stationId,
    required String membershipId,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  });

  Future<String> resetEmployeePassword({
    required String stationId,
    required String userId,
    String? newPassword,
  });

  Future<void> revokeEmployeeSessions({
    required String stationId,
    required String userId,
  });
}

class SupabaseEmployeeRepository implements EmployeeRepository {
  final SupabaseClient _client;

  SupabaseEmployeeRepository(this._client);

  @override
  Future<List<EmployeeDetails>> getStationEmployees({
    required String stationId,
    String? search,
    StationRole? role,
    MembershipStatus? status,
  }) async {
    try {
      final res = await _client.rpc(
        'admin_get_station_members',
        params: {
          'p_station_id': stationId,
          'p_search': search != null && search.isNotEmpty ? search : null,
          'p_role': role?.value,
          'p_status': status?.value,
        },
      );

      final list = (res as List<dynamic>?) ?? [];
      return list
          .map((item) => EmployeeDetails.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is PostgrestException) {
        throw DatabaseFailure(e.message, code: e.code, originalError: e);
      }
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<Map<String, dynamic>> createEmployee({
    required String stationId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required StationRole role,
    String? employeeCode,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-create-employee',
        body: {
          'station_id': stationId,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': email?.trim(),
          'phone': phone?.trim(),
          'role': role.value,
          'employee_code': employeeCode?.trim(),
        },
      );

      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final err = data['error'];
          String msg = 'Failed to provision employee';
          String code = 'CREATION_FAILED';
          if (err is Map) {
            msg = err['message']?.toString() ?? msg;
            code = err['code']?.toString() ?? code;
          } else if (err is String) {
            msg = err;
          }
          throw UnknownFailure(msg, code: code);
        }
        return data;
      }
      throw const UnknownFailure(
          'Unexpected server response from employee creation');
    } catch (e) {
      if (e is AppFailure) rethrow;
      if (e is FunctionException) {
        String msg = e.reasonPhrase ?? 'Edge Function invocation failed';
        String code = e.status.toString();
        if (e.details is Map) {
          final det = e.details as Map;
          msg = det['message']?.toString() ?? det['error']?.toString() ?? msg;
          code = det['code']?.toString() ?? code;
        } else if (e.details is String) {
          msg = e.details as String;
        }
        throw UnknownFailure(msg, code: code, originalError: e);
      }
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateEmployeeProfile({
    required String stationId,
    required String userId,
    required String membershipId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? preferredLocale,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async {
    try {
      // 1. Attempt edge function for full profile + email update
      final response = await _client.functions.invoke(
        'admin-update-employee',
        body: {
          'station_id': stationId,
          'user_id': userId,
          'membership_id': membershipId,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': email?.trim(),
          'phone': phone?.trim(),
          'preferred_locale': preferredLocale ?? 'he',
          'role': role.value,
          'status': status.value,
          'employee_code': employeeCode?.trim(),
        },
      );

      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final err = data['error'];
          String msg = 'Failed to update employee';
          String code = 'UPDATE_FAILED';
          if (err is Map) {
            msg = err['message']?.toString() ?? msg;
            code = err['code']?.toString() ?? code;
          } else if (err is String) {
            msg = err;
          }
          throw UnknownFailure(msg, code: code);
        }
        return data;
      }
      return {'success': true};
    } catch (e) {
      final allowAdminProfileFallback = role == StationRole.admin &&
          (e is AppFailure
              ? e.code == 'P00105'
              : e.toString().contains('P00105'));
      if (e is AppFailure && !allowAdminProfileFallback) rethrow;

      // If Edge Function is unavailable or rejects ADMIN membership mutation,
      // fall back to the profile RPC. Station Manager profile fields (including
      // self) are allowed; grant/revoke of ADMIN remains P00105.
      try {
        await _client.rpc(
          'admin_update_employee_profile',
          params: {
            'p_station_id': stationId,
            'p_target_user_id': userId,
            'p_first_name': firstName.trim(),
            'p_last_name': lastName.trim(),
            'p_phone':
                phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
            'p_preferred_locale': preferredLocale ?? 'he',
          },
        );

        if (role != StationRole.admin) {
          await _client.rpc(
            'admin_update_membership',
            params: {
              'p_station_id': stationId,
              'p_membership_id': membershipId,
              'p_role': role.value,
              'p_status': status.value,
              'p_employee_code':
                  employeeCode != null && employeeCode.trim().isNotEmpty
                      ? employeeCode.trim()
                      : null,
            },
          );
        }

        return {'success': true};
      } catch (rpcErr) {
        if (rpcErr is PostgrestException) {
          if (rpcErr.code == 'P0001' ||
              rpcErr.message.contains('last active Administrator')) {
            throw const DatabaseFailure(
              'Cannot demote or deactivate the last active Administrator of this station.',
              code: 'P0001',
            );
          }
          if (rpcErr.code == '23505') {
            throw const DatabaseFailure(
              'This phone number is already associated with another account.',
              code: '23505',
            );
          }
          throw DatabaseFailure(rpcErr.message,
              code: rpcErr.code, originalError: rpcErr);
        }
        throw UnknownFailure(rpcErr.toString(), originalError: rpcErr);
      }
    }
  }

  @override
  Future<void> updateMembership({
    required String stationId,
    required String membershipId,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async {
    try {
      await _client.rpc(
        'admin_update_membership',
        params: {
          'p_station_id': stationId,
          'p_membership_id': membershipId,
          'p_role': role.value,
          'p_status': status.value,
          'p_employee_code': employeeCode != null && employeeCode.isNotEmpty
              ? employeeCode
              : null,
        },
      );
    } catch (e) {
      if (e is PostgrestException) {
        if (e.code == 'P0001' ||
            e.message.contains('last active Administrator')) {
          throw const DatabaseFailure(
            'Cannot demote or deactivate the last active Administrator of this station.',
            code: 'P0001',
          );
        }
        throw DatabaseFailure(e.message, code: e.code, originalError: e);
      }
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  static String _generateSecureTempPassword() {
    const chars =
        r'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*';
    final rand = Random.secure();
    final buffer = StringBuffer('Ys#');
    for (int i = 0; i < 9; i++) {
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  @override
  Future<String> resetEmployeePassword({
    required String stationId,
    required String userId,
    String? newPassword,
  }) async {
    final passwordToSet = newPassword?.trim();
    final effectivePassword =
        (passwordToSet != null && passwordToSet.isNotEmpty)
            ? passwordToSet
            : _generateSecureTempPassword();

    // 1. Primary path: Direct PostgreSQL RPC (instantaneous, 100% reliable)
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
      // 2. Secondary fallback: Edge Function if RPC is not yet registered in database
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
        if (data != null && data is Map<String, dynamic>) {
          if (data.containsKey('error')) {
            final err = data['error'];
            String msg = 'Password reset failed';
            String code = 'RESET_FAILED';
            if (err is Map) {
              msg = err['message']?.toString() ?? msg;
              code = err['code']?.toString() ?? code;
            } else if (err is String) {
              msg = err;
            }
            throw UnknownFailure(msg, code: code);
          }
          return data['temporary_password'] as String? ?? effectivePassword;
        }
        return effectivePassword;
      } catch (e) {
        if (rpcErr is PostgrestException && rpcErr.code != 'PGRST202') {
          throw DatabaseFailure(rpcErr.message,
              code: rpcErr.code, originalError: rpcErr);
        }
        if (e is AppFailure) rethrow;
        if (e is FunctionException) {
          String msg = e.reasonPhrase ?? 'Password reset failed';
          String code = e.status.toString();
          if (e.details is Map) {
            final det = e.details as Map;
            msg =
                det['message']?.toString() ?? det['error']?.toString() ?? msg;
            code = det['code']?.toString() ?? code;
          } else if (e.details is String) {
            msg = e.details as String;
          }
          throw UnknownFailure(msg, code: code, originalError: e);
        }
        throw UnknownFailure(e.toString(), originalError: e);
      }
    }
  }

  @override
  Future<void> revokeEmployeeSessions({
    required String stationId,
    required String userId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-revoke-sessions',
        body: {
          'station_id': stationId,
          'user_id': userId,
        },
      );

      final data = response.data;
      if (data != null &&
          data is Map<String, dynamic> &&
          data.containsKey('error')) {
        final err = data['error'];
        String msg = 'Failed to revoke sessions';
        String code = 'REVOKE_FAILED';
        if (err is Map) {
          msg = err['message']?.toString() ?? msg;
          code = err['code']?.toString() ?? code;
        } else if (err is String) {
          msg = err;
        }
        throw UnknownFailure(msg, code: code);
      }
    } catch (e) {
      if (e is AppFailure) rethrow;
      if (e is FunctionException) {
        String msg = e.reasonPhrase ?? 'Failed to revoke sessions';
        String code = e.status.toString();
        if (e.details is Map) {
          final det = e.details as Map;
          msg = det['message']?.toString() ?? det['error']?.toString() ?? msg;
          code = det['code']?.toString() ?? code;
        } else if (e.details is String) {
          msg = e.details as String;
        }
        throw UnknownFailure(msg, code: code, originalError: e);
      }
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseEmployeeRepository(client);
});
