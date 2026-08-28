import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/audit_log_entry.dart';

abstract class AuditRepository {
  Future<AuditLogQueryResult> queryAuditLogs({
    required String stationId,
    DateTime? from,
    DateTime? to,
    String? actionCategory,
    String? actorId,
    String? search,
    int limit = 50,
    int offset = 0,
  });
}

class SupabaseAuditRepository implements AuditRepository {
  final SupabaseClient _client;

  SupabaseAuditRepository(this._client);

  @override
  Future<AuditLogQueryResult> queryAuditLogs({
    required String stationId,
    DateTime? from,
    DateTime? to,
    String? actionCategory,
    String? actorId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _client.rpc('admin_query_audit_logs', params: {
        'p_station_id': stationId,
        if (from != null) 'p_from': from.toIso8601String(),
        if (to != null) 'p_to': to.toIso8601String(),
        if (actionCategory != null &&
            actionCategory.isNotEmpty &&
            actionCategory != 'ALL')
          'p_action_category': actionCategory,
        if (actorId != null && actorId.isNotEmpty) 'p_actor_id': actorId,
        if (search != null && search.trim().isNotEmpty)
          'p_search': search.trim(),
        'p_limit': limit,
        'p_offset': offset,
      });

      final list = res as List<dynamic>? ?? [];
      if (list.isEmpty) {
        return const AuditLogQueryResult(items: [], totalCount: 0);
      }

      int totalCount = 0;
      final items = list.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (totalCount == 0 && map['total_count'] != null) {
          totalCount = (map['total_count'] as num).toInt();
        }
        return AuditLogEntry.fromJson(map);
      }).toList();

      return AuditLogQueryResult(
        items: items,
        totalCount: totalCount > 0 ? totalCount : items.length,
      );
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuditRepository(client);
});
