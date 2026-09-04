import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/attendance_record.dart';
import '../domain/models/live_attendance_roster.dart';

class AttendanceRepository {
  final SupabaseClient _supabase;

  AttendanceRepository(this._supabase);

  /// Unified Server-Authoritative NFC attendance (Check-in & Check-out via URL token)
  Future<Map<String, dynamic>> nfcProcessAttendance({
    required String token,
    Map<String, dynamic>? clientLocation,
  }) async {
    final res = await _supabase.rpc('nfc_process_attendance', params: {
      'p_token': token.trim(),
      if (clientLocation != null) 'p_client_location': clientLocation,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Server-Authoritative NFC Check-In
  Future<Map<String, dynamic>> nfcCheckIn({
    required String tagIdentifier,
    required String tagSecret,
  }) async {
    final res = await _supabase.rpc('nfc_check_in', params: {
      'p_tag_identifier': tagIdentifier.trim(),
      'p_tag_secret': tagSecret.trim(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Server-Authoritative NFC Check-Out
  Future<Map<String, dynamic>> nfcCheckOut({
    required String tagIdentifier,
    required String tagSecret,
  }) async {
    final res = await _supabase.rpc('nfc_check_out', params: {
      'p_tag_identifier': tagIdentifier.trim(),
      'p_tag_secret': tagSecret.trim(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<LiveAttendanceResponse> getManagerLiveAttendance({
    required String stationId,
    String? targetDate,
  }) async {
    final res = await _supabase.rpc('get_manager_live_attendance', params: {
      'p_station_id': stationId,
      if (targetDate != null) 'p_target_date': targetDate,
    });
    return LiveAttendanceResponse.fromJson(
        Map<String, dynamic>.from(res as Map));
  }

  Future<List<AttendanceRecord>> getMyAttendanceHistory({
    required String stationId,
    DateTime? from,
    DateTime? to,
    int limit = 20,
    int offset = 0,
  }) async {
    final now = DateTime.now();
    final fromDate = from ?? now.subtract(const Duration(days: 90));
    final toDate = to ?? now.add(const Duration(days: 1));

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final res = await _supabase.rpc('get_my_attendance_history', params: {
      'p_from': formatDate(fromDate),
      'p_to': formatDate(toDate),
      'p_station_id': stationId,
      'p_limit': limit,
      'p_offset': offset,
    });
    final map = Map<String, dynamic>.from(res as Map);
    final rawList = (map['items'] ?? map['records']) as List<dynamic>?;
    final recordsList = rawList
            ?.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return recordsList;
  }

  Future<AttendanceRecord?> getMyOpenAttendance(String stationId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final res = await _supabase
        .from('attendance_records')
        .select()
        .eq('employee_user_id', uid)
        .eq('station_id', stationId)
        .isFilter('check_out_time', null)
        .maybeSingle();

    if (res == null) return null;
    return AttendanceRecord.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> correctAttendanceRecord({
    required String attendanceRecordId,
    required DateTime newCheckIn,
    required DateTime newCheckOut,
    required String reason,
  }) async {
    await _supabase.rpc('correct_attendance_record', params: {
      'p_attendance_record_id': attendanceRecordId,
      'p_new_check_in': newCheckIn.toUtc().toIso8601String(),
      'p_new_check_out': newCheckOut.toUtc().toIso8601String(),
      'p_reason': reason.trim(),
    });
  }
}
