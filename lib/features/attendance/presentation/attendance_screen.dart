import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/domain/station_membership.dart';
import '../../stations/presentation/active_station_provider.dart';
import 'employee_attendance_screen.dart';
import 'manager_live_attendance_screen.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider);
    final isManagerOrAdmin = activeMembership?.role == StationRole.admin ||
        activeMembership?.role == StationRole.shiftManager;

    if (isManagerOrAdmin) {
      return const ManagerLiveAttendanceScreen();
    } else {
      return const EmployeeAttendanceScreen();
    }
  }
}
