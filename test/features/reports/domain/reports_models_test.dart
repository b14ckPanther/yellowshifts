import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_summary.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_history_item.dart';
import 'package:yellowshifts/features/reports/domain/models/open_attendance_session.dart';
import 'package:yellowshifts/features/reports/domain/models/station_attendance_summary.dart';
import 'package:yellowshifts/features/reports/domain/models/employee_attendance_summary.dart';
import 'package:yellowshifts/features/reports/domain/models/daily_attendance_report.dart';
import 'package:yellowshifts/features/reports/domain/models/attendance_correction_detail.dart';

void main() {
  group('OpenAttendanceSession Model Tests', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'station_id': '22222222-2222-2222-2222-222222222222',
        'station_name': 'Station North',
        'check_in_time': '2026-08-20T08:00:00.000Z',
        'shift_name_snapshot': 'Morning Shift',
        'scheduled_start_at_snapshot': '2026-08-20T08:00:00.000Z',
        'scheduled_end_at_snapshot': '2026-08-20T16:00:00.000Z',
        'elapsed_minutes': 120,
        'needs_attention': false,
      };

      final session = OpenAttendanceSession.fromJson(json);
      expect(session.id, equals('11111111-1111-1111-1111-111111111111'));
      expect(session.stationName, equals('Station North'));
      expect(session.elapsedMinutes, equals(120));
      expect(session.needsAttention, isFalse);
    });

    test('parses anomaly >16h flag correctly', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'station_id': '22222222-2222-2222-2222-222222222222',
        'station_name': 'Station North',
        'check_in_time': '2026-08-19T08:00:00.000Z',
        'elapsed_minutes': 1000,
        'needs_attention': true,
      };

      final session = OpenAttendanceSession.fromJson(json);
      expect(session.elapsedMinutes, equals(1000));
      expect(session.needsAttention, isTrue);
    });
  });

  group('AttendanceSummary Model Tests', () {
    test('parses summary with active open session and calculates hours', () {
      final json = {
        'success': true,
        'from_date': '2026-08-01',
        'to_date': '2026-08-31',
        'station_id': '11111111-1111-1111-1111-111111111111',
        'total_worked_minutes': 2400,
        'completed_shifts': 5,
        'late_shifts': 2,
        'total_late_minutes': 30,
        'corrected_records': 1,
        'open_session_count': 1,
        'stations_worked_count': 1,
        'first_shift_date': '2026-08-03',
        'last_shift_date': '2026-08-28',
        'active_open_session': {
          'id': '99999999-9999-9999-9999-999999999999',
          'station_id': '11111111-1111-1111-1111-111111111111',
          'station_name': 'Station North',
          'check_in_time': '2026-08-30T08:00:00.000Z',
          'elapsed_minutes': 45,
          'needs_attention': false,
        }
      };

      final summary = AttendanceSummary.fromJson(json);
      expect(summary.success, isTrue);
      expect(summary.totalWorkedMinutes, equals(2400));
      expect(summary.totalWorkedHours, equals(40.0));
      expect(summary.totalLateHours, equals(0.5));
      expect(summary.completedShifts, equals(5));
      expect(summary.lateShifts, equals(2));
      expect(summary.activeOpenSession, isNotNull);
      expect(summary.activeOpenSession!.elapsedMinutes, equals(45));
    });

    test('creates empty summary with safe defaults', () {
      final empty = AttendanceSummary.empty();
      expect(empty.totalWorkedMinutes, equals(0));
      expect(empty.totalWorkedHours, equals(0.0));
      expect(empty.completedShifts, equals(0));
      expect(empty.activeOpenSession, isNull);
    });
  });

  group('AttendanceHistoryItem Model Tests', () {
    test('parses history item with late and corrected flags', () {
      final json = {
        'id': 'item-1',
        'station_id': 'st-1',
        'station_name': 'Station North',
        'station_code': 'STA-N',
        'shift_name_snapshot': 'Night Shift',
        'check_in_time': '2026-08-15T22:15:00.000Z',
        'check_out_time': '2026-08-16T06:15:00.000Z',
        'worked_minutes': 480,
        'late_minutes': 15,
        'status': 'COMPLETED',
        'verification_method': 'KIOSK_QR',
        'operational_date': '2026-08-15',
        'is_late': true,
        'is_corrected': true,
        'correction_count': 2,
        'created_at': '2026-08-15T22:15:00.000Z',
      };

      final item = AttendanceHistoryItem.fromJson(json);
      expect(item.id, equals('item-1'));
      expect(item.isOpen, isFalse);
      expect(item.isLate, isTrue);
      expect(item.isCorrected, isTrue);
      expect(item.workedHours, equals(8.0));
      expect(item.correctionCount, equals(2));
    });

    test('detects open attendance item', () {
      final json = {
        'id': 'item-2',
        'station_id': 'st-1',
        'station_name': 'Station North',
        'station_code': 'STA-N',
        'check_in_time': '2026-08-16T08:00:00.000Z',
        'check_out_time': null,
        'worked_minutes': null,
        'late_minutes': 0,
        'status': 'OPEN',
        'verification_method': 'KIOSK_QR',
        'operational_date': '2026-08-16',
        'is_late': false,
        'is_corrected': false,
        'correction_count': 0,
        'created_at': '2026-08-16T08:00:00.000Z',
      };

      final item = AttendanceHistoryItem.fromJson(json);
      expect(item.isOpen, isTrue);
      expect(item.workedMinutes, isNull);
      expect(item.workedHours, equals(0.0));
    });
  });

  group('StationAttendanceSummary Model Tests', () {
    test('parses station summary with on-time rate and avg duration', () {
      final json = {
        'success': true,
        'station_id': 'st-1',
        'station_name': 'Station North',
        'from_date': '2026-08-01',
        'to_date': '2026-08-31',
        'total_worked_minutes': 4800,
        'completed_shifts': 10,
        'late_shifts': 1,
        'total_late_minutes': 10,
        'corrected_records': 2,
        'open_sessions': 1,
        'employees_with_attendance_count': 5,
        'active_employees_count': 8,
        'repeated_lateness_employee_count': 0,
      };

      final summary = StationAttendanceSummary.fromJson(json);
      expect(summary.totalWorkedHours, equals(80.0));
      expect(summary.averageShiftHours, equals(8.0));
      expect(summary.onTimePercentage, equals(90.0));
    });

    test('handles 0 completed shifts gracefully without division by zero', () {
      final empty = StationAttendanceSummary.empty();
      expect(empty.averageShiftHours, equals(0.0));
      expect(empty.onTimePercentage, equals(100.0));
    });
  });

  group('EmployeeAttendanceSummary Model Tests', () {
    test('parses employee summary with repeated lateness', () {
      final json = {
        'employee_user_id': 'u-1',
        'first_name': 'Charlie',
        'last_name': 'Worker',
        'employee_code': 'EMP-001',
        'membership_status': 'ACTIVE',
        'station_role': 'EMPLOYEE',
        'total_worked_minutes': 2400,
        'completed_shifts': 5,
        'late_shifts': 3,
        'total_late_minutes': 45,
        'corrected_records': 1,
        'open_session_count': 0,
        'has_repeated_lateness': true,
        'first_shift_date': '2026-08-01',
        'last_shift_date': '2026-08-10',
      };

      final emp = EmployeeAttendanceSummary.fromJson(json);
      expect(emp.fullName, equals('Charlie Worker'));
      expect(emp.isInactive, isFalse);
      expect(emp.hasRepeatedLateness, isTrue);
      expect(emp.totalWorkedHours, equals(40.0));
    });
  });

  group('DailyAttendanceReport Model Tests', () {
    test('parses daily report and computes shortage count', () {
      final json = {
        'success': true,
        'station_id': 'st-1',
        'station_name': 'Station North',
        'date': '2026-08-20',
        'day_summary': {
          'total_worked_minutes': 960,
          'completed_shifts': 2,
          'late_shifts': 0,
          'open_sessions': 0,
          'walk_in_count': 1,
        },
        'shifts': [
          {
            'shift_id': 'sh-1',
            'shift_name': 'Morning Shift',
            'starts_at': '2026-08-20T08:00:00.000Z',
            'ends_at': '2026-08-20T16:00:00.000Z',
            'required_staff_count': 3,
            'assigned_count': 2,
            'checked_in_count': 2,
            'completed_count': 2,
            'late_count': 0,
            'open_count': 0,
            'attendance_records': [
              {
                'record_id': 'r-1',
                'user_id': 'u-1',
                'first_name': 'Charlie',
                'last_name': 'Worker',
                'employee_code': 'EMP-001',
                'check_in_time': '2026-08-20T08:00:00.000Z',
                'check_out_time': '2026-08-20T16:00:00.000Z',
                'worked_minutes': 480,
                'late_minutes': 0,
                'status': 'COMPLETED',
                'verification_method': 'KIOSK_QR',
                'is_corrected': false,
              }
            ]
          }
        ],
        'walk_ins': [
          {
            'record_id': 'w-1',
            'user_id': 'u-2',
            'first_name': 'David',
            'last_name': 'Helper',
            'employee_code': 'EMP-002',
            'check_in_time': '2026-08-20T10:00:00.000Z',
            'check_out_time': '2026-08-20T14:00:00.000Z',
            'worked_minutes': 240,
            'late_minutes': 0,
            'status': 'COMPLETED',
            'verification_method': 'KIOSK_QR',
            'is_corrected': false,
          }
        ]
      };

      final report = DailyAttendanceReport.fromJson(json);
      expect(report.success, isTrue);
      expect(report.totalWorkedHours, equals(16.0));
      expect(report.shifts.length, equals(1));
      expect(report.shifts[0].unassignedCount,
          equals(1)); // 3 required - 2 assigned = 1
      expect(report.walkIns.length, equals(1));
    });
  });

  group('AttendanceCorrectionDetail & Drilldown Model Tests', () {
    test('parses employee drilldown and ordered corrections ledger', () {
      final json = {
        'success': true,
        'station_id': 'st-1',
        'station_name': 'Station North',
        'employee': {
          'id': 'u-1',
          'first_name': 'Charlie',
          'last_name': 'Worker',
          'employee_code': 'EMP-001',
          'membership_status': 'ACTIVE',
          'station_role': 'EMPLOYEE',
        },
        'from_date': '2026-08-01',
        'to_date': '2026-08-31',
        'summary': {
          'total_worked_minutes': 480,
          'completed_shifts': 1,
          'late_shifts': 0,
          'total_late_minutes': 0,
          'corrected_records': 1,
          'has_repeated_lateness': false,
        },
        'records': [
          {
            'id': 'rec-1',
            'shift_name_snapshot': 'Morning Shift',
            'check_in_time': '2026-08-10T08:00:00.000Z',
            'check_out_time': '2026-08-10T16:00:00.000Z',
            'worked_minutes': 480,
            'late_minutes': 0,
            'status': 'COMPLETED',
            'verification_method': 'KIOSK_QR',
            'operational_date': '2026-08-10',
            'is_late': false,
            'corrections': [
              {
                'id': 'corr-1',
                'actor_user_id': 'adm-1',
                'actor_name': 'Alice Admin',
                'previous_worked_minutes': 450,
                'new_worked_minutes': 480,
                'reason': 'Adjusted checkout time per supervisor log',
                'created_at': '2026-08-10T17:00:00.000Z',
              }
            ],
            'created_at': '2026-08-10T08:00:00.000Z',
          }
        ]
      };

      final drilldown = StationEmployeeAttendanceDetailResponse.fromJson(json);
      expect(drilldown.success, isTrue);
      expect(drilldown.employee.fullName, equals('Charlie Worker'));
      expect(drilldown.records.length, equals(1));
      expect(drilldown.records[0].isCorrected, isTrue);
      expect(
          drilldown.records[0].corrections[0].actorName, equals('Alice Admin'));
    });
  });
}
