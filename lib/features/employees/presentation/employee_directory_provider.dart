import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../stations/domain/station_membership.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/employee_repository.dart';
import '../domain/employee_details.dart';

class EmployeeDirectoryState {
  final String searchQuery;
  final StationRole? selectedRole;
  final MembershipStatus? selectedStatus;
  final List<EmployeeDetails> employees;
  final bool isLoading;
  final String? error;
  final EmployeeDetails? selectedEmployee;

  const EmployeeDirectoryState({
    this.searchQuery = '',
    this.selectedRole,
    this.selectedStatus,
    this.employees = const [],
    this.isLoading = false,
    this.error,
    this.selectedEmployee,
  });

  EmployeeDirectoryState copyWith({
    String? searchQuery,
    StationRole? selectedRole,
    bool clearRole = false,
    MembershipStatus? selectedStatus,
    bool clearStatus = false,
    List<EmployeeDetails>? employees,
    bool? isLoading,
    String? error,
    bool clearError = false,
    EmployeeDetails? selectedEmployee,
    bool clearSelected = false,
  }) {
    return EmployeeDirectoryState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRole: clearRole ? null : (selectedRole ?? this.selectedRole),
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedEmployee:
          clearSelected ? null : (selectedEmployee ?? this.selectedEmployee),
    );
  }
}

class EmployeeDirectoryNotifier extends StateNotifier<EmployeeDirectoryState> {
  final EmployeeRepository _repository;
  final Ref _ref;
  Timer? _debounceTimer;

  EmployeeDirectoryNotifier(this._repository, this._ref)
      : super(const EmployeeDirectoryState()) {
    loadEmployees();
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    try {
      final isTest =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (isTest) return;

      final client = _ref.read(supabaseClientProvider);

      final activeStationId = _ref.read(activeStationIdProvider);
      if (activeStationId == null) return;

      final channel = client
          .channel('realtime:employees:$activeStationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'station_memberships',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'station_id',
              value: activeStationId,
            ),
            callback: (_) => loadEmployees(silent: true),
          )
          .subscribe();

      _ref.onDispose(() {
        try {
          client.removeChannel(channel);
        } catch (_) {}
        _debounceTimer?.cancel();
      });
    } catch (_) {
      // Supabase client uninitialized in unit test harnesses
    }
  }

  Future<void> loadEmployees({bool silent = false}) async {
    final stationId = _ref.read(activeStationIdProvider);
    final access = _ref.read(stationAccessContextProvider);
    if (stationId == null || !access.canManageEmployees) {
      state = state.copyWith(isLoading: false);
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final list = await _repository.getStationEmployees(
        stationId: stationId,
        search: state.searchQuery,
        role: state.selectedRole,
        status: state.selectedStatus,
      );

      EmployeeDetails? updatedSelected;
      if (state.selectedEmployee != null) {
        updatedSelected = list.cast<EmployeeDetails?>().firstWhere(
              (e) => e?.membershipId == state.selectedEmployee?.membershipId,
              orElse: () => null,
            );
      }

      state = state.copyWith(
        employees: list,
        isLoading: false,
        selectedEmployee:
            updatedSelected ?? (list.isNotEmpty ? list.first : null),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AppFailure: ', ''),
      );
    }
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadEmployees();
    });
  }

  void setRoleFilter(StationRole? role) {
    if (state.selectedRole == role) {
      state = state.copyWith(clearRole: true);
    } else {
      state = state.copyWith(selectedRole: role);
    }
    loadEmployees();
  }

  void setStatusFilter(MembershipStatus? status) {
    if (state.selectedStatus == status) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status);
    }
    loadEmployees();
  }

  void selectEmployee(EmployeeDetails? employee) {
    state = state.copyWith(selectedEmployee: employee);
  }

  Future<void> updateEmployeeProfile({
    required String userId,
    required String membershipId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? preferredLocale,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) throw Exception('No active station selected');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateEmployeeProfile(
        stationId: stationId,
        userId: userId,
        membershipId: membershipId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        preferredLocale: preferredLocale,
        role: role,
        status: status,
        employeeCode: employeeCode,
      );
      await loadEmployees();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AppFailure: ', ''),
      );
      rethrow;
    }
  }

  Future<void> updateRole(String membershipId, StationRole newRole) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) return;

    final currentEmployee =
        state.employees.firstWhere((e) => e.membershipId == membershipId);
    if (newRole == StationRole.admin ||
        currentEmployee.role == StationRole.admin) {
      throw const StationAdminRoleForbiddenFailure(
        'Station administrators cannot grant or revoke Station Manager privileges',
      );
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.updateMembership(
        stationId: stationId,
        membershipId: membershipId,
        role: newRole,
        status: currentEmployee.status,
        employeeCode: currentEmployee.employeeCode,
      );
      await loadEmployees();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AppFailure: ', ''),
      );
      rethrow;
    }
  }

  Future<void> updateStatus(
      String membershipId, MembershipStatus newStatus) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) return;

    final currentEmployee =
        state.employees.firstWhere((e) => e.membershipId == membershipId);
    if (currentEmployee.role == StationRole.admin) {
      throw const StationAdminRoleForbiddenFailure(
        'Station administrators cannot grant or revoke Station Manager privileges',
      );
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.updateMembership(
        stationId: stationId,
        membershipId: membershipId,
        role: currentEmployee.role,
        status: newStatus,
        employeeCode: currentEmployee.employeeCode,
      );
      await loadEmployees();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AppFailure: ', ''),
      );
      rethrow;
    }
  }

  Future<String> resetPassword(String userId, {String? newPassword}) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) throw Exception('No active station selected');

    return await _repository.resetEmployeePassword(
      stationId: stationId,
      userId: userId,
      newPassword: newPassword,
    );
  }

  Future<void> revokeSessions(String userId) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) throw Exception('No active station selected');

    await _repository.revokeEmployeeSessions(
      stationId: stationId,
      userId: userId,
    );
  }
}

final employeeDirectoryProvider =
    StateNotifierProvider<EmployeeDirectoryNotifier, EmployeeDirectoryState>(
        (ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  return EmployeeDirectoryNotifier(repository, ref);
});
