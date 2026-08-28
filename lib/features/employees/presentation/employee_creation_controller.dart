import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/domain/station_membership.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/employee_repository.dart';
import 'employee_directory_provider.dart';

class EmployeeCreationResult {
  final bool isNewUser;
  final String userId;
  final String membershipId;
  final String? email;
  final String? temporaryPassword;
  final String status;

  const EmployeeCreationResult({
    required this.isNewUser,
    required this.userId,
    required this.membershipId,
    this.email,
    this.temporaryPassword,
    required this.status,
  });
}

class EmployeeCreationState {
  final bool isLoading;
  final String? error;
  final EmployeeCreationResult? result;

  const EmployeeCreationState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  EmployeeCreationState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    EmployeeCreationResult? result,
    bool clearResult = false,
  }) {
    return EmployeeCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class EmployeeCreationController extends StateNotifier<EmployeeCreationState> {
  final EmployeeRepository _repository;
  final Ref _ref;

  EmployeeCreationController(this._repository, this._ref)
      : super(const EmployeeCreationState());

  Future<EmployeeCreationResult> createEmployee({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required StationRole role,
    String? employeeCode,
  }) async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) {
      throw Exception('No active station selected');
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearResult: true);

    try {
      final res = await _repository.createEmployee(
        stationId: stationId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        role: role,
        employeeCode: employeeCode,
      );

      final creationResult = EmployeeCreationResult(
        isNewUser: res['is_new_user'] as bool? ?? false,
        userId: res['user_id'] as String? ?? '',
        membershipId: res['membership_id'] as String? ?? '',
        email: res['email'] as String?,
        temporaryPassword: res['temporary_password'] as String?,
        status: res['status'] as String? ?? 'SUCCESS',
      );

      state = state.copyWith(isLoading: false, result: creationResult);

      // Refresh directory and pulse
      _ref.read(employeeDirectoryProvider.notifier).loadEmployees(silent: true);

      return creationResult;
    } catch (e) {
      final errorMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('AppFailure: ', '');
      state = state.copyWith(isLoading: false, error: errorMsg);
      rethrow;
    }
  }

  void reset() {
    state = const EmployeeCreationState();
  }
}

final employeeCreationControllerProvider =
    StateNotifierProvider<EmployeeCreationController, EmployeeCreationState>(
        (ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  return EmployeeCreationController(repository, ref);
});
