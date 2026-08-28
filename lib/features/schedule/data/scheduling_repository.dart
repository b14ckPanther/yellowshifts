import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/work_schedule.dart';
import '../domain/models/schedule_candidate.dart';
import '../domain/models/schedule_validation_result.dart';
import '../domain/models/my_shift.dart';

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  return SchedulingRepository(Supabase.instance.client);
});

class SchedulingRepository {
  final SupabaseClient _client;

  SchedulingRepository(this._client);

  /// Create a Work Schedule from a Phase 2 frozen availability period
  Future<WorkSchedule> createWorkSchedule(String availabilityPeriodId) async {
    final response = await _client.rpc(
      'create_work_schedule',
      params: {'p_availability_period_id': availabilityPeriodId},
    );
    final data = Map<String, dynamic>.from(response as Map);
    final scheduleId = data['schedule_id'] as String;
    return getScheduleDetails(scheduleId);
  }

  /// Get complete work schedule details (shifts, assignments, staffing counts)
  Future<WorkSchedule> getScheduleDetails(String scheduleId) async {
    final response = await _client.rpc(
      'get_schedule_details',
      params: {'p_schedule_id': scheduleId},
    );
    final data = Map<String, dynamic>.from(response as Map);
    return WorkSchedule.fromJson(data);
  }

  /// Get work schedule for station and week start date
  Future<WorkSchedule?> getScheduleByWeek(
      String stationId, DateTime weekStartDate) async {
    final dateStr =
        '${weekStartDate.year.toString().padLeft(4, '0')}-${weekStartDate.month.toString().padLeft(2, '0')}-${weekStartDate.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('work_schedules')
        .select('id')
        .eq('station_id', stationId)
        .eq('week_start_date', dateStr)
        .maybeSingle();

    if (rows == null) return null;
    return getScheduleDetails(rows['id'] as String);
  }

  /// Get candidates for shift assignment with availability and conflict analysis
  Future<List<ScheduleCandidate>> getShiftCandidates(
    String scheduleShiftId, {
    String? search,
    String filter = 'ALL',
  }) async {
    final response = await _client.rpc(
      'get_shift_assignment_candidates',
      params: {
        'p_schedule_shift_id': scheduleShiftId,
        'p_search': search,
        'p_filter': filter,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    final candidatesList = data['candidates'] as List<dynamic>? ?? [];
    return candidatesList
        .map((c) => ScheduleCandidate.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Assign employee to a shift atomically with OCC version check
  Future<Map<String, dynamic>> assignEmployee({
    required String scheduleShiftId,
    required String membershipId,
    required int expectedVersion,
    bool override = false,
    String? overrideReason,
    String? changeReason,
  }) async {
    final response = await _client.rpc(
      'assign_employee_to_shift',
      params: {
        'p_schedule_shift_id': scheduleShiftId,
        'p_membership_id': membershipId,
        'p_expected_version': expectedVersion,
        'p_override': override,
        'p_override_reason': overrideReason,
        'p_change_reason': changeReason,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Remove an assignment atomically with OCC version increment
  Future<int> removeAssignment({
    required String assignmentId,
    required int expectedVersion,
    String? changeReason,
  }) async {
    final response = await _client.rpc(
      'remove_shift_assignment',
      params: {
        'p_assignment_id': assignmentId,
        'p_expected_version': expectedVersion,
        'p_change_reason': changeReason,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    return (data['new_version'] as num).toInt();
  }

  /// Move an assignment from one shift to another atomically
  Future<int> moveAssignment({
    required String assignmentId,
    required String targetShiftId,
    required int expectedVersion,
    bool override = false,
    String? overrideReason,
    String? changeReason,
  }) async {
    final response = await _client.rpc(
      'move_shift_assignment',
      params: {
        'p_assignment_id': assignmentId,
        'p_target_shift_id': targetShiftId,
        'p_expected_version': expectedVersion,
        'p_override': override,
        'p_override_reason': overrideReason,
        'p_change_reason': changeReason,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    return (data['new_version'] as num).toInt();
  }

  /// Update schedule shift required staff count
  Future<int> updateStaffing({
    required String scheduleShiftId,
    required int requiredCount,
    required int expectedVersion,
    String? changeReason,
  }) async {
    final response = await _client.rpc(
      'update_schedule_shift_staffing',
      params: {
        'p_schedule_shift_id': scheduleShiftId,
        'p_required_count': requiredCount,
        'p_expected_version': expectedVersion,
        'p_change_reason': changeReason,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    return (data['new_version'] as num).toInt();
  }

  /// Run comprehensive pre-publish validation on a work schedule
  Future<ScheduleValidationResult> validateSchedule(String scheduleId) async {
    final response = await _client.rpc(
      'validate_work_schedule',
      params: {'p_schedule_id': scheduleId},
    );
    final data = Map<String, dynamic>.from(response as Map);
    return ScheduleValidationResult.fromJson(data);
  }

  /// Publish a work schedule atomically with warning confirmation
  Future<Map<String, dynamic>> publishSchedule({
    required String scheduleId,
    required int expectedVersion,
    bool confirmWarnings = false,
  }) async {
    final response = await _client.rpc(
      'publish_work_schedule',
      params: {
        'p_schedule_id': scheduleId,
        'p_expected_version': expectedVersion,
        'p_confirm_warnings': confirmWarnings,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Get employee's published shifts for the active station and week
  Future<MyShiftsResponse> getMyShifts({
    required String stationId,
    required DateTime weekStartDate,
  }) async {
    final dateStr =
        '${weekStartDate.year.toString().padLeft(4, '0')}-${weekStartDate.month.toString().padLeft(2, '0')}-${weekStartDate.day.toString().padLeft(2, '0')}';
    final response = await _client.rpc(
      'get_my_shifts',
      params: {
        'p_station_id': stationId,
        'p_week_start_date': dateStr,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    return MyShiftsResponse.fromJson(data);
  }
}
