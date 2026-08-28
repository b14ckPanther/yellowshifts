import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/presence_proof.dart';
import '../domain/models/attendance_record.dart';
import '../domain/models/live_attendance_roster.dart';

class AttendanceRepository {
  final SupabaseClient _supabase;

  AttendanceRepository(this._supabase);

  Future<PresenceProof> scanAttendanceQr(String qrTokenOrCode) async {
    final res = await _supabase.rpc('scan_attendance_qr', params: {
      'p_qr_token_or_code': qrTokenOrCode.trim(),
    });
    return PresenceProof.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> checkInWithPresenceProof(
    String presenceProofToken, {
    String? identityProofToken,
  }) async {
    final res = await _supabase.rpc('check_in_with_presence_proof', params: {
      'p_presence_proof_token': presenceProofToken.trim(),
      if (identityProofToken != null && identityProofToken.isNotEmpty)
        'p_identity_proof_token': identityProofToken.trim(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> checkOutWithPresenceProof(
    String presenceProofToken, {
    String? identityProofToken,
  }) async {
    final res = await _supabase.rpc('check_out_with_presence_proof', params: {
      'p_presence_proof_token': presenceProofToken.trim(),
      if (identityProofToken != null && identityProofToken.isNotEmpty)
        'p_identity_proof_token': identityProofToken.trim(),
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
