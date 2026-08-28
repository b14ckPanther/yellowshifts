import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../../stations/domain/station_membership.dart';
import 'employee_availability_screen.dart';
import 'manager_availability_screen.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider);
    final isManagerOrAdmin = activeMembership?.role == StationRole.admin ||
        activeMembership?.role == StationRole.shiftManager;

    if (isManagerOrAdmin) {
      return const ManagerAvailabilityScreen();
    }

    return const EmployeeAvailabilityScreen();
  }
}
