import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/attendance_repository.dart';
import '../../domain/models/attendance_record.dart';
import '../../domain/models/live_attendance_roster.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../stations/presentation/active_station_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AttendanceRepository(client);
});

final currentOpenAttendanceProvider =
    FutureProvider.autoDispose<AttendanceRecord?>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return null;

  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getMyOpenAttendance(stationId);
});

final myAttendanceHistoryProvider =
    FutureProvider.autoDispose<List<AttendanceRecord>>((ref) async {
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return [];

  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getMyAttendanceHistory(stationId: stationId);
});

final managerLiveAttendanceProvider = FutureProvider.autoDispose
    .family<LiveAttendanceResponse, String>((ref, stationId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getManagerLiveAttendance(stationId: stationId);
});

final attendanceRealtimeSubscriptionProvider =
    StreamProvider.autoDispose<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final stationId = ref.watch(activeStationIdProvider);
  if (stationId == null) return const Stream.empty();

  final channel = client
      .channel('public:attendance_records:$stationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'attendance_records',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'station_id',
          value: stationId,
        ),
        callback: (payload) {
          ref.invalidate(currentOpenAttendanceProvider);
          ref.invalidate(myAttendanceHistoryProvider);
          ref.invalidate(managerLiveAttendanceProvider(stationId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });

  return const Stream.empty();
});
