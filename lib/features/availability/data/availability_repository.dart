import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/availability_period.dart';
import '../domain/availability_submission.dart';
import '../domain/availability_matrix.dart';

abstract class AvailabilityRepository {
  Future<AvailabilityPeriod?> getCurrentAvailabilityPeriod(String stationId);
  Future<List<AvailabilityPeriod>> listAvailabilityPeriods(String stationId);
  Future<AvailabilityPeriod> getAvailabilityPeriod(String periodId);
  Future<String> createAvailabilityPeriod({
    required String stationId,
    required DateTime weekStartDate,
    required DateTime submissionDeadline,
    String? notes,
  });
  Future<void> openAvailabilityPeriod(String periodId);
  Future<void> closeAvailabilityPeriod(String periodId);
  Future<void> reopenAvailabilityPeriod(String periodId, DateTime newDeadline);

  Future<EmployeeAvailabilitySubmission?> getMySubmission(String periodId);
  Future<void> saveDraft({
    required String periodId,
    required List<Map<String, dynamic>> entries,
  });
  Future<void> submitAvailability({
    required String periodId,
    required List<Map<String, dynamic>> entries,
  });

  Future<AvailabilityMatrix> getAvailabilityMatrix({
    required String periodId,
    String? search,
    String? statusFilter,
    String? roleFilter,
  });
}

class SupabaseAvailabilityRepository implements AvailabilityRepository {
  final SupabaseClient _client;

  SupabaseAvailabilityRepository(this._client);

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<AvailabilityPeriod?> getCurrentAvailabilityPeriod(
      String stationId) async {
    try {
      final res = await _client.rpc('get_current_availability_period', params: {
        'p_station_id': stationId,
      });

      final map = res as Map<String, dynamic>;
      if (map['has_active_period'] != true || map['period'] == null) {
        return null;
      }

      return AvailabilityPeriod.fromJson(map['period'] as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<List<AvailabilityPeriod>> listAvailabilityPeriods(
      String stationId) async {
    try {
      final periods = await _client
          .from('availability_periods')
          .select('*, templates:availability_period_shift_templates(*)')
          .eq('station_id', stationId)
          .order('week_start_date', ascending: false);

      return (periods as List).map((row) {
        final map = row as Map<String, dynamic>;
        return AvailabilityPeriod.fromJson(map);
      }).toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<AvailabilityPeriod> getAvailabilityPeriod(String periodId) async {
    try {
      final row = await _client
          .from('availability_periods')
          .select('*, templates:availability_period_shift_templates(*)')
          .eq('id', periodId)
          .single();

      return AvailabilityPeriod.fromJson(row);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<String> createAvailabilityPeriod({
    required String stationId,
    required DateTime weekStartDate,
    required DateTime submissionDeadline,
    String? notes,
  }) async {
    try {
      final res = await _client.rpc('create_availability_period', params: {
        'p_station_id': stationId,
        'p_week_start_date': _formatDate(weekStartDate),
        'p_submission_deadline': submissionDeadline.toUtc().toIso8601String(),
        'p_notes': notes,
      });

      final map = res as Map<String, dynamic>;
      return map['period_id'] as String;
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> openAvailabilityPeriod(String periodId) async {
    try {
      await _client.rpc('open_availability_period', params: {
        'p_period_id': periodId,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> closeAvailabilityPeriod(String periodId) async {
    try {
      await _client.rpc('close_availability_period', params: {
        'p_period_id': periodId,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> reopenAvailabilityPeriod(
      String periodId, DateTime newDeadline) async {
    try {
      await _client.rpc('reopen_availability_period', params: {
        'p_period_id': periodId,
        'p_new_deadline': newDeadline.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<EmployeeAvailabilitySubmission?> getMySubmission(
      String periodId) async {
    try {
      final res = await _client.rpc('get_my_availability_submission', params: {
        'p_period_id': periodId,
      });

      return EmployeeAvailabilitySubmission.fromJson(
          res as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> saveDraft({
    required String periodId,
    required List<Map<String, dynamic>> entries,
  }) async {
    try {
      await _client.rpc('save_availability_draft', params: {
        'p_period_id': periodId,
        'p_entries': entries,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<void> submitAvailability({
    required String periodId,
    required List<Map<String, dynamic>> entries,
  }) async {
    try {
      await _client.rpc('submit_availability', params: {
        'p_period_id': periodId,
        'p_entries': entries,
      });
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  @override
  Future<AvailabilityMatrix> getAvailabilityMatrix({
    required String periodId,
    String? search,
    String? statusFilter,
    String? roleFilter,
  }) async {
    try {
      final res = await _client.rpc('get_availability_matrix', params: {
        'p_period_id': periodId,
        'p_search': search,
        'p_status_filter': statusFilter,
        'p_role_filter': roleFilter,
      });

      return AvailabilityMatrix.fromJson(res as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }
}

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return SupabaseAvailabilityRepository(Supabase.instance.client);
});
