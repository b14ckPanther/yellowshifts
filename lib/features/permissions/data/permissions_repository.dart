import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/shift_manager_permissions.dart';

abstract class PermissionsRepository {
  Future<ShiftManagerPermissions> getShiftManagerPermissions(String stationId);
  Future<void> updateShiftManagerPermissions(
      String stationId, ShiftManagerPermissions permissions);
}

class SupabasePermissionsRepository implements PermissionsRepository {
  final SupabaseClient _client;

  SupabasePermissionsRepository(this._client);

  @override
  Future<ShiftManagerPermissions> getShiftManagerPermissions(
      String stationId) async {
    try {
      final res = await _client.rpc('get_shift_manager_permissions', params: {
        'p_station_id': stationId,
      });

      final map = res as Map<String, dynamic>;
      return ShiftManagerPermissions.fromJson(map);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> updateShiftManagerPermissions(
      String stationId, ShiftManagerPermissions permissions) async {
    try {
      await _client.rpc('admin_set_shift_manager_permissions', params: {
        'p_station_id': stationId,
        'p_permissions': permissions.toJson(),
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }
}

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  return SupabasePermissionsRepository(Supabase.instance.client);
});
