import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/station_system_health.dart';

abstract class SystemHealthRepository {
  Future<StationSystemHealth> getStationSystemHealth(String stationId);
}

class SupabaseSystemHealthRepository implements SystemHealthRepository {
  final SupabaseClient _client;

  SupabaseSystemHealthRepository(this._client);

  @override
  Future<StationSystemHealth> getStationSystemHealth(String stationId) async {
    try {
      final res = await _client.rpc('get_station_system_health', params: {
        'p_station_id': stationId,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return StationSystemHealth.fromJson(map);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }
}

final systemHealthRepositoryProvider = Provider<SystemHealthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSystemHealthRepository(client);
});
