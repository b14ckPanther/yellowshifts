import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../../stations/domain/station_membership.dart';
import 'manager_schedule_screen.dart';
import 'my_shifts_screen.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider);
    final isManagerOrAdmin = activeMembership?.role == StationRole.admin ||
        activeMembership?.role == StationRole.shiftManager;

    if (isManagerOrAdmin) {
      return const ManagerScheduleScreen();
    }

    return const MyShiftsScreen();
  }
}
