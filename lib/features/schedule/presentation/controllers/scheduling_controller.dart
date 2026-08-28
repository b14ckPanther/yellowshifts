import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../../data/scheduling_repository.dart';
import '../../domain/models/work_schedule.dart';
import '../../domain/models/schedule_candidate.dart';
import '../../domain/models/schedule_validation_result.dart';
import '../../domain/models/my_shift.dart';

DateTime _calculateWeekStart(DateTime date, int weekStartDay) {
  final cleanDate = DateTime(date.year, date.month, date.day);
  final currentWeekday = cleanDate.weekday % 7; // Sunday = 0
  final diff = (currentWeekday - weekStartDay + 7) % 7;
  return cleanDate.subtract(Duration(days: diff));
}

/// Selected schedule week start date
final selectedScheduleWeekProvider = StateProvider<DateTime>((ref) {
  final activeMembership = ref.watch(activeMembershipProvider);
  final weekStart = activeMembership?.station?.weekStart ?? 0;
  return _calculateWeekStart(DateTime.now(), weekStart);
});

/// Active work schedule provider for selected station & week
final activeScheduleProvider =
    FutureProvider.autoDispose<WorkSchedule?>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  final weekStart = ref.watch(selectedScheduleWeekProvider);
  if (stationId == null) return null;

  final repository = ref.watch(schedulingRepositoryProvider);
  final schedule = await repository.getScheduleByWeek(stationId, weekStart);

  // Setup Realtime subscription for schedule updates
  final channel = Supabase.instance.client
      .channel('public:work_schedules:$stationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'work_schedules',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'station_id',
          value: stationId,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shift_assignments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'station_id',
          value: stationId,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
  });

  return schedule;
});

/// Shift Candidates Provider
final shiftCandidatesProvider = FutureProvider.family.autoDispose<
    List<ScheduleCandidate>,
    ({String shiftId, String? search, String filter})>((ref, arg) async {
  final repository = ref.watch(schedulingRepositoryProvider);
  return repository.getShiftCandidates(
    arg.shiftId,
    search: arg.search,
    filter: arg.filter,
  );
});

/// Schedule Validation Provider
final scheduleValidationProvider = FutureProvider.family
    .autoDispose<ScheduleValidationResult, String>((ref, scheduleId) async {
  final repository = ref.watch(schedulingRepositoryProvider);
  return repository.validateSchedule(scheduleId);
});

/// Employee My Shifts Provider
final myShiftsProvider =
    FutureProvider.autoDispose<MyShiftsResponse>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  final weekStart = ref.watch(selectedScheduleWeekProvider);
  if (stationId == null) {
    return MyShiftsResponse(
      hasPublishedSchedule: false,
      stationId: '',
      weekStartDate: weekStart,
    );
  }

  final repository = ref.watch(schedulingRepositoryProvider);
  final response = await repository.getMyShifts(
    stationId: stationId,
    weekStartDate: weekStart,
  );

  // Subscribe to realtime shifts
  final channel = Supabase.instance.client
      .channel('public:my_shifts:$stationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shift_assignments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'station_id',
          value: stationId,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
  });

  return response;
});

/// Controller for executing scheduling mutations
final schedulingControllerProvider =
    AsyncNotifierProvider<SchedulingController, void>(() {
  return SchedulingController();
});

class SchedulingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> assignEmployee({
    required String scheduleShiftId,
    required String membershipId,
    required int expectedVersion,
    bool override = false,
    String? overrideReason,
    String? changeReason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.assignEmployee(
        scheduleShiftId: scheduleShiftId,
        membershipId: membershipId,
        expectedVersion: expectedVersion,
        override: override,
        overrideReason: overrideReason,
        changeReason: changeReason,
      );
      ref.invalidate(activeScheduleProvider);
    });
  }

  Future<void> removeAssignment({
    required String assignmentId,
    required int expectedVersion,
    String? changeReason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.removeAssignment(
        assignmentId: assignmentId,
        expectedVersion: expectedVersion,
        changeReason: changeReason,
      );
      ref.invalidate(activeScheduleProvider);
    });
  }

  Future<void> moveAssignment({
    required String assignmentId,
    required String targetShiftId,
    required int expectedVersion,
    bool override = false,
    String? overrideReason,
    String? changeReason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.moveAssignment(
        assignmentId: assignmentId,
        targetShiftId: targetShiftId,
        expectedVersion: expectedVersion,
        override: override,
        overrideReason: overrideReason,
        changeReason: changeReason,
      );
      ref.invalidate(activeScheduleProvider);
    });
  }

  Future<void> updateStaffing({
    required String scheduleShiftId,
    required int requiredCount,
    required int expectedVersion,
    String? changeReason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.updateStaffing(
        scheduleShiftId: scheduleShiftId,
        requiredCount: requiredCount,
        expectedVersion: expectedVersion,
        changeReason: changeReason,
      );
      ref.invalidate(activeScheduleProvider);
    });
  }

  Future<void> publishSchedule({
    required String scheduleId,
    required int expectedVersion,
    bool confirmWarnings = false,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(schedulingRepositoryProvider);
      await repository.publishSchedule(
        scheduleId: scheduleId,
        expectedVersion: expectedVersion,
        confirmWarnings: confirmWarnings,
      );
      ref.invalidate(activeScheduleProvider);
      ref.invalidate(myShiftsProvider);
    });
  }
}
