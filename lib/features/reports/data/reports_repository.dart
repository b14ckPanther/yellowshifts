import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/attendance_summary.dart';
import '../domain/models/attendance_history_item.dart';
import '../domain/models/station_attendance_summary.dart';
import '../domain/models/employee_attendance_summary.dart';
import '../domain/models/daily_attendance_report.dart';
import '../domain/models/attendance_correction_detail.dart';
import '../domain/models/report_export_model.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReportsRepository(supabase);
});

class ReportsRepository {
  final SupabaseClient _supabase;

  ReportsRepository(this._supabase);

  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<AttendanceSummary> getMyAttendanceSummary({
    required DateTime from,
    required DateTime to,
    String? stationId,
  }) async {
    final res = await _supabase.rpc('get_my_attendance_summary', params: {
      'p_from': formatDate(from),
      'p_to': formatDate(to),
      if (stationId != null && stationId.isNotEmpty) 'p_station_id': stationId,
    });
    return AttendanceSummary.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> getMyAttendanceHistory({
    required DateTime from,
    required DateTime to,
    String? stationId,
    String? statusFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    final res = await _supabase.rpc('get_my_attendance_history', params: {
      'p_from': formatDate(from),
      'p_to': formatDate(to),
      if (stationId != null && stationId.isNotEmpty) 'p_station_id': stationId,
      if (statusFilter != null && statusFilter.isNotEmpty)
        'p_status_filter': statusFilter,
      'p_limit': limit,
      'p_offset': offset,
    });

    final data = Map<String, dynamic>.from(res as Map);
    final rawItems = data['items'] as List? ?? [];
    final items = rawItems
        .map((e) =>
            AttendanceHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return {
      'items': items,
      'total_count': (data['total_count'] as num?)?.toInt() ?? 0,
      'limit': (data['limit'] as num?)?.toInt() ?? limit,
      'offset': (data['offset'] as num?)?.toInt() ?? offset,
      'has_more': data['has_more'] as bool? ?? false,
    };
  }

  Future<StationAttendanceSummary> getStationAttendanceSummary({
    required String stationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _supabase.rpc('get_station_attendance_summary', params: {
      'p_station_id': stationId,
      'p_from': formatDate(from),
      'p_to': formatDate(to),
    });
    return StationAttendanceSummary.fromJson(
        Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> getStationEmployeeAttendanceSummary({
    required String stationId,
    required DateTime from,
    required DateTime to,
    String? search,
    String sortBy = 'name',
    String sortOrder = 'asc',
    int limit = 25,
    int offset = 0,
  }) async {
    final res =
        await _supabase.rpc('get_station_employee_attendance_summary', params: {
      'p_station_id': stationId,
      'p_from': formatDate(from),
      'p_to': formatDate(to),
      if (search != null && search.trim().isNotEmpty) 'p_search': search.trim(),
      'p_sort_by': sortBy,
      'p_sort_order': sortOrder,
      'p_limit': limit,
      'p_offset': offset,
    });

    final data = Map<String, dynamic>.from(res as Map);
    final rawItems = data['items'] as List? ?? [];
    final items = rawItems
        .map((e) => EmployeeAttendanceSummary.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();

    return {
      'items': items,
      'total_count': (data['total_count'] as num?)?.toInt() ?? 0,
      'limit': (data['limit'] as num?)?.toInt() ?? limit,
      'offset': (data['offset'] as num?)?.toInt() ?? offset,
      'has_more': data['has_more'] as bool? ?? false,
    };
  }

  Future<DailyAttendanceReport> getStationDailyAttendanceReport({
    required String stationId,
    required DateTime date,
  }) async {
    final res =
        await _supabase.rpc('get_station_daily_attendance_report', params: {
      'p_station_id': stationId,
      'p_date': formatDate(date),
    });
    return DailyAttendanceReport.fromJson(
        Map<String, dynamic>.from(res as Map));
  }

  Future<StationEmployeeAttendanceDetailResponse>
      getStationEmployeeAttendanceDetail({
    required String stationId,
    required String employeeUserId,
    required DateTime from,
    required DateTime to,
  }) async {
    final res =
        await _supabase.rpc('get_station_employee_attendance_detail', params: {
      'p_station_id': stationId,
      'p_employee_user_id': employeeUserId,
      'p_from': formatDate(from),
      'p_to': formatDate(to),
    });
    return StationEmployeeAttendanceDetailResponse.fromJson(
        Map<String, dynamic>.from(res as Map));
  }

  // --------------------------------------------------------------------------
  // Phase 8: Operational Export Engine RPCs & Edge Function Integrations
  // --------------------------------------------------------------------------

  Future<String> requestExport({
    String? stationId,
    required ReportExportType exportType,
    ExportFormat format = ExportFormat.csv,
    Map<String, dynamic> filterPayload = const {},
  }) async {
    final res = await _supabase.rpc('request_report_export', params: {
      if (stationId != null && stationId.isNotEmpty) 'p_station_id': stationId,
      'p_export_type': exportType.value,
      'p_format': format.value,
      'p_filter_payload': filterPayload,
    });
    final map = Map<String, dynamic>.from(res as Map);
    return map['export_id'] as String;
  }

  Future<ExportGenerationResult> generateExport({
    required String exportId,
  }) async {
    try {
      // First try invoking the high-performance Edge Function for persistent storage and signed download URL
      final response = await _supabase.functions.invoke(
        'generate-report-export',
        body: {'export_id': exportId},
      );

      if (response.status == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return ExportGenerationResult.fromJson(data);
      } else if (response.data != null &&
          response.data is Map &&
          (response.data as Map)['error'] != null) {
        final errMap =
            Map<String, dynamic>.from((response.data as Map)['error'] as Map);
        final code = errMap['code']?.toString();
        final msg = errMap['message']?.toString() ?? 'Export failed';
        if (code == 'FORBIDDEN') {
          throw PermissionDeniedFailure(msg, code: '42501');
        } else if (code == 'EXPORT_EXPIRED') {
          throw DatabaseFailure(msg, code: 'P0081');
        }
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      // Fallback directly to client-evaluated SQL RPC if Edge Function is unreachable
    }

    // Direct fallback to server SQL RPC
    final res = await _supabase.rpc('generate_report_export_csv', params: {
      'p_export_id': exportId,
    });
    final map = Map<String, dynamic>.from(res as Map);
    return ExportGenerationResult.fromJson(map);
  }

  Future<List<ReportExportItem>> getRecentExports({
    String? stationId,
    int limit = 25,
  }) async {
    var query = _supabase.from('report_exports').select();
    if (stationId != null && stationId.isNotEmpty) {
      query = query.eq('station_id', stationId);
    }
    final res = await query.order('created_at', ascending: false).limit(limit);
    final list = res as List? ?? [];
    return list
        .map((e) =>
            ReportExportItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
