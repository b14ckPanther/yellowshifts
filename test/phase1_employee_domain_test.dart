import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';
import 'package:yellowshifts/features/employees/domain/employee_details.dart';
import 'package:yellowshifts/features/employees/presentation/employee_creation_controller.dart';
import 'package:yellowshifts/features/employees/data/employee_repository.dart';

class MockEmployeeRepository implements EmployeeRepository {
  final List<EmployeeDetails> mockEmployees;

  MockEmployeeRepository([this.mockEmployees = const []]);

  @override
  Future<List<EmployeeDetails>> getStationEmployees({
    required String stationId,
    String? search,
    StationRole? role,
    MembershipStatus? status,
  }) async {
    return mockEmployees.where((e) {
      if (role != null && e.role != role) return false;
      if (status != null && e.status != status) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return e.firstName.toLowerCase().contains(q) ||
            e.lastName.toLowerCase().contains(q) ||
            (e.employeeCode?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> createEmployee({
    required String stationId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required StationRole role,
    String? employeeCode,
  }) async {
    return {
      'status': 'NEW_USER_CREATED',
      'user_id': 'mock-new-user-id',
      'membership_id': 'mock-new-mem-id',
      'email': email ?? 'mock@station.local',
      'temporary_password': 'Ys#MockPass123',
      'is_new_user': true,
    };
  }

  @override
  Future<Map<String, dynamic>> updateEmployeeProfile({
    required String stationId,
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
    return {'success': true};
  }

  @override
  Future<void> updateMembership({
    required String stationId,
    required String membershipId,
    required StationRole role,
    required MembershipStatus status,
    String? employeeCode,
  }) async {}

  @override
  Future<String> resetEmployeePassword({
    required String stationId,
    required String userId,
    String? newPassword,
  }) async {
    return newPassword ?? 'Ys#ResetPass456';
  }

  @override
  Future<void> revokeEmployeeSessions({
    required String stationId,
    required String userId,
  }) async {}
}

void main() {
  group('EmployeeDetails Domain Model', () {
    test('Correctly computes fullName and initials', () {
      final emp = EmployeeDetails(
        membershipId: 'mem-1',
        stationId: 'sta-1',
        userId: 'user-1',
        role: StationRole.admin,
        status: MembershipStatus.active,
        employeeCode: 'ADM-001',
        joinedAt: DateTime(2026, 1, 1),
        firstName: 'David',
        lastName: 'Cohen',
        phone: '+972-50-1234567',
      );

      expect(emp.fullName, 'David Cohen');
      expect(emp.initials, 'DC');
      expect(emp.isAdmin, isTrue);
      expect(emp.isShiftManager, isFalse);
      expect(emp.isEmployee, isFalse);
      expect(emp.isActive, isTrue);
    });

    test('Serializes to and from JSON cleanly', () {
      final json = {
        'membership_id': 'mem-2',
        'station_id': 'sta-1',
        'user_id': 'user-2',
        'role': 'SHIFT_MANAGER',
        'status': 'ACTIVE',
        'employee_code': 'MGR-002',
        'joined_at': '2026-02-01T10:00:00.000Z',
        'first_name': 'Sarah',
        'last_name': 'Levi',
        'phone': '+972-52-9876543',
        'preferred_locale': 'he',
        'avatar_url': null,
      };

      final emp = EmployeeDetails.fromJson(json);
      expect(emp.membershipId, 'mem-2');
      expect(emp.firstName, 'Sarah');
      expect(emp.lastName, 'Levi');
      expect(emp.role, StationRole.shiftManager);
      expect(emp.employeeCode, 'MGR-002');

      final serialized = emp.toJson();
      expect(serialized['role'], 'SHIFT_MANAGER');
      expect(serialized['employee_code'], 'MGR-002');
    });
  });

  group('StationMembership Model with EmployeeCode', () {
    test('Serializes employeeCode correctly', () {
      final mem = StationMembership(
        id: 'mem-1',
        stationId: 'sta-1',
        userId: 'usr-1',
        role: StationRole.employee,
        status: MembershipStatus.active,
        employeeCode: 'EMP-777',
        joinedAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      expect(mem.employeeCode, 'EMP-777');
      final json = mem.toJson();
      expect(json['employee_code'], 'EMP-777');

      final parsed = StationMembership.fromJson(json);
      expect(parsed.employeeCode, 'EMP-777');
      expect(parsed.role, StationRole.employee);
    });
  });

  group('EmployeeCreationResult', () {
    test('Captures temporary password and flags', () {
      const result = EmployeeCreationResult(
        isNewUser: true,
        userId: 'usr-new',
        membershipId: 'mem-new',
        email: 'user@station.com',
        temporaryPassword: 'Ys#Pass123456',
        status: 'NEW_USER_CREATED',
      );

      expect(result.isNewUser, isTrue);
      expect(result.temporaryPassword, 'Ys#Pass123456');
      expect(result.status, 'NEW_USER_CREATED');
    });
  });

  group('Employee Password Reset', () {
    test('Reset password with custom password returns custom password',
        () async {
      final repo = MockEmployeeRepository();
      final result = await repo.resetEmployeePassword(
        stationId: 'sta-1',
        userId: 'user-1',
        newPassword: 'MyCustomSecurePassword123!',
      );

      expect(result, 'MyCustomSecurePassword123!');
    });

    test('Reset password without custom password returns generated password',
        () async {
      final repo = MockEmployeeRepository();
      final result = await repo.resetEmployeePassword(
        stationId: 'sta-1',
        userId: 'user-1',
      );

      expect(result, 'Ys#ResetPass456');
    });
  });
}
