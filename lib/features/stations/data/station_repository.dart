import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/station.dart';

abstract class StationRepository {
  Future<Station?> getStationById(String stationId);
  Future<List<Station>> getUserStations();
  Future<void> updateStation(Station station,
      {bool forceDeactivate = false, String? deactivationReason});
  Future<Map<String, dynamic>> getStationPulse(String stationId);
}

class SupabaseStationRepository implements StationRepository {
  final SupabaseClient _client;

  SupabaseStationRepository(this._client);

  @override
  Future<Station?> getStationById(String stationId) async {
    try {
      final response = await _client
          .from('stations')
          .select()
          .eq('id', stationId)
          .maybeSingle();

      if (response == null) return null;
      return Station.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<List<Station>> getUserStations() async {
    try {
      final response = await _client.from('stations').select().order('name');

      return (response as List<dynamic>)
          .map((json) => Station.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<void> updateStation(Station station,
      {bool forceDeactivate = false, String? deactivationReason}) async {
    try {
      await _client.rpc('admin_update_station', params: {
        'p_station_id': station.id,
        'p_name': station.name,
        'p_code': station.code,
        'p_timezone': station.timezone,
        'p_locale': station.locale,
        'p_week_start': station.weekStart,
        'p_is_active': station.isActive,
        'p_late_grace_minutes': station.lateGraceMinutes,
        'p_check_in_early_minutes': station.checkInEarlyMinutes,
        'p_force_deactivate': forceDeactivate,
        if (deactivationReason != null)
          'p_deactivation_reason': deactivationReason,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<Map<String, dynamic>> getStationPulse(String stationId) async {
    try {
      final response = await _client.rpc('get_station_pulse_counts', params: {
        'p_station_id': stationId,
      });
      return response as Map<String, dynamic>? ?? {};
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }
}

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseStationRepository(client);
});
