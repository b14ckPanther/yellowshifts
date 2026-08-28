import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/shift_template.dart';

abstract class ShiftTemplateRepository {
  Future<List<ShiftTemplate>> getStationTemplates(String stationId,
      {bool activeOnly = false});
  Future<ShiftTemplate> createTemplate({
    required String stationId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
  });
  Future<ShiftTemplate> updateTemplate({
    required String stationId,
    required String templateId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
    bool isActive = true,
  });
  Future<void> reorderTemplates(String stationId, List<String> templateIds);
  Future<void> deactivateTemplate(String stationId, String templateId);
  Future<void> reactivateTemplate(String stationId, String templateId);
}

class SupabaseShiftTemplateRepository implements ShiftTemplateRepository {
  final SupabaseClient _client;

  SupabaseShiftTemplateRepository(this._client);

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  @override
  Future<List<ShiftTemplate>> getStationTemplates(String stationId,
      {bool activeOnly = false}) async {
    try {
      var query =
          _client.from('shift_templates').select().eq('station_id', stationId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final res = await query
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return (res as List)
          .map((row) => ShiftTemplate.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<ShiftTemplate> createTemplate({
    required String stationId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _client.rpc('admin_manage_shift_template', params: {
        'p_station_id': stationId,
        'p_template_id': null,
        'p_name': name,
        'p_code': code,
        'p_start_time': _formatTime(startTime),
        'p_end_time': _formatTime(endTime),
        'p_sort_order': sortOrder,
        'p_is_active': true,
        'p_action': 'UPSERT',
      });

      final map = res as Map<String, dynamic>;
      final templateId = map['template_id'] as String;

      final rows = await _client
          .from('shift_templates')
          .select()
          .eq('id', templateId)
          .single();
      return ShiftTemplate.fromJson(rows);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<ShiftTemplate> updateTemplate({
    required String stationId,
    required String templateId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    try {
      await _client.rpc('admin_manage_shift_template', params: {
        'p_station_id': stationId,
        'p_template_id': templateId,
        'p_name': name,
        'p_code': code,
        'p_start_time': _formatTime(startTime),
        'p_end_time': _formatTime(endTime),
        'p_sort_order': sortOrder,
        'p_is_active': isActive,
        'p_action': 'UPSERT',
      });

      final rows = await _client
          .from('shift_templates')
          .select()
          .eq('id', templateId)
          .single();
      return ShiftTemplate.fromJson(rows);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> reorderTemplates(
      String stationId, List<String> templateIds) async {
    try {
      await _client.rpc('admin_reorder_shift_templates', params: {
        'p_station_id': stationId,
        'p_template_ids': templateIds,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> deactivateTemplate(String stationId, String templateId) async {
    try {
      await _client.rpc('admin_manage_shift_template', params: {
        'p_station_id': stationId,
        'p_template_id': templateId,
        'p_action': 'DEACTIVATE',
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> reactivateTemplate(String stationId, String templateId) async {
    try {
      await _client.rpc('admin_manage_shift_template', params: {
        'p_station_id': stationId,
        'p_template_id': templateId,
        'p_action': 'REACTIVATE',
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }
}

final shiftTemplateRepositoryProvider =
    Provider<ShiftTemplateRepository>((ref) {
  return SupabaseShiftTemplateRepository(Supabase.instance.client);
});
