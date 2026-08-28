import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yellowshifts/features/schedule/domain/models/work_schedule.dart';
import 'package:yellowshifts/features/schedule/domain/models/work_schedule_shift.dart';
import 'package:yellowshifts/features/schedule/domain/models/shift_assignment.dart';
import 'package:yellowshifts/features/schedule/domain/models/schedule_candidate.dart';
import 'package:yellowshifts/features/schedule/domain/models/schedule_validation_result.dart';
import 'package:yellowshifts/features/schedule/domain/models/my_shift.dart';
import 'package:yellowshifts/features/schedule/presentation/widgets/app_day_strip.dart';
import 'package:yellowshifts/features/schedule/presentation/widgets/shift_card.dart';

void main() {
  group('Phase 3 Domain Model Tests', () {
    test('WorkSchedule parsing & staffing coverage calculation', () {
      final now = DateTime.now();
      final schedule = WorkSchedule(
        id: 'sched-1',
        stationId: 'sta-1',
        stationName: 'תחנת יילו כורדני',
        stationTimezone: 'Asia/Jerusalem',
        availabilityPeriodId: 'per-1',
        weekStartDate: DateTime(2026, 9, 6),
        status: WorkScheduleStatus.draft,
        version: 1,
        createdBy: 'usr-1',
        createdAt: now,
        updatedAt: now,
        shifts: [
          WorkScheduleShift(
            id: 'shift-1',
            workScheduleId: 'sched-1',
            stationId: 'sta-1',
            operationalDate: DateTime(2026, 9, 6),
            periodShiftTemplateId: 'tmpl-1',
            shiftName: 'בוקר',
            startTime: '07:00',
            endTime: '15:00',
            startsAt: DateTime(2026, 9, 6, 7, 0),
            endsAt: DateTime(2026, 9, 6, 15, 0),
            requiredStaffCount: 2,
            assignedStaffCount: 2,
            sortOrder: 0,
          ),
          WorkScheduleShift(
            id: 'shift-2',
            workScheduleId: 'sched-1',
            stationId: 'sta-1',
            operationalDate: DateTime(2026, 9, 6),
            periodShiftTemplateId: 'tmpl-2',
            shiftName: 'ערב',
            startTime: '15:00',
            endTime: '23:00',
            startsAt: DateTime(2026, 9, 6, 15, 0),
            endsAt: DateTime(2026, 9, 6, 23, 0),
            requiredStaffCount: 2,
            assignedStaffCount: 1,
            sortOrder: 1,
          ),
        ],
      );

      expect(schedule.isDraft, isTrue);
      expect(schedule.isPublished, isFalse);
      expect(schedule.totalShiftsCount, equals(2));
      expect(schedule.totalAssignmentsCount, equals(3));
      expect(schedule.fullyStaffedShiftsCount, equals(1));
      expect(schedule.understaffedShiftsCount, equals(1));
      expect(schedule.staffingCoveragePercent, equals(75.0));
    });

    test('WorkScheduleShift cross-midnight & staffing state derivation', () {
      final dayShift = WorkScheduleShift(
        id: 'shift-d',
        workScheduleId: 'sched-1',
        stationId: 'sta-1',
        operationalDate: DateTime(2026, 9, 6),
        periodShiftTemplateId: 'tmpl-1',
        shiftName: 'בוקר',
        startTime: '07:00',
        endTime: '15:00',
        startsAt: DateTime(2026, 9, 6, 7, 0),
        endsAt: DateTime(2026, 9, 6, 15, 0),
        requiredStaffCount: 2,
        assignedStaffCount: 1,
        sortOrder: 0,
      );

      final nightShift = WorkScheduleShift(
        id: 'shift-n',
        workScheduleId: 'sched-1',
        stationId: 'sta-1',
        operationalDate: DateTime(2026, 9, 6),
        periodShiftTemplateId: 'tmpl-3',
        shiftName: 'לילה',
        startTime: '23:00',
        endTime: '07:00',
        startsAt: DateTime(2026, 9, 6, 23, 0),
        endsAt: DateTime(2026, 9, 7, 7, 0),
        requiredStaffCount: 1,
        assignedStaffCount: 1,
        sortOrder: 2,
      );

      expect(dayShift.isCrossMidnight, isFalse);
      expect(dayShift.staffingState, equals(StaffingState.understaffed));
      expect(dayShift.plannedDuration.inHours, equals(8));

      expect(nightShift.isCrossMidnight, isTrue);
      expect(nightShift.staffingState, equals(StaffingState.fullyStaffed));
      expect(nightShift.plannedDuration.inHours, equals(8));
    });

    test('ScheduleCandidate availability & override requirements', () {
      const availCand = ScheduleCandidate(
        membershipId: 'mem-1',
        userId: 'usr-1',
        firstName: 'דוד',
        lastName: 'כהן',
        role: 'EMPLOYEE',
        alreadyAssigned: false,
        availabilityState: CandidateAvailabilityState.available,
        conflictState: CandidateConflictState.none,
        weeklyShiftsCount: 3,
      );

      const unavailCand = ScheduleCandidate(
        membershipId: 'mem-2',
        userId: 'usr-2',
        firstName: 'שרה',
        lastName: 'לוי',
        role: 'EMPLOYEE',
        alreadyAssigned: false,
        availabilityState: CandidateAvailabilityState.unavailable,
        conflictState: CandidateConflictState.none,
        weeklyShiftsCount: 2,
      );

      const conflictCand = ScheduleCandidate(
        membershipId: 'mem-3',
        userId: 'usr-3',
        firstName: 'נועם',
        lastName: 'כץ',
        role: 'EMPLOYEE',
        alreadyAssigned: false,
        availabilityState: CandidateAvailabilityState.available,
        conflictState: CandidateConflictState.crossStationOverlap,
        weeklyShiftsCount: 1,
      );

      expect(availCand.requiresOverride, isFalse);
      expect(unavailCand.requiresOverride, isTrue);
      expect(conflictCand.conflictState.hasConflict, isTrue);
    });

    test('ScheduleValidationResult hard errors and canPublish flag', () {
      const valFail = ScheduleValidationResult(
        scheduleId: 'sched-1',
        isValid: false,
        canPublish: false,
        hardErrorsCount: 1,
        warningsCount: 2,
        hardErrors: [
          ScheduleValidationError(
            code: 'INACTIVE_MEMBERSHIP',
            message: 'Employee is inactive',
          ),
        ],
        warnings: [
          ScheduleValidationError(
            code: 'UNDERSTAFFED_SHIFT',
            message: 'Morning shift understaffed',
          ),
        ],
        summary: ScheduleStaffingSummary(
          totalShifts: 21,
          fullyStaffedShifts: 20,
          understaffedShifts: 1,
          overstaffedShifts: 0,
          totalAssignments: 25,
        ),
      );

      expect(valFail.isValid, isFalse);
      expect(valFail.canPublish, isFalse);
      expect(valFail.hardErrors.length, equals(1));
      expect(valFail.warnings.length, equals(1));
    });

    test('MyShiftsResponse states parsing', () {
      final noSched = MyShiftsResponse.fromJson(const {
        'has_published_schedule': false,
        'station_id': 'sta-1',
        'week_start_date': '2026-09-06',
        'shifts': [],
      });
      expect(noSched.hasPublishedSchedule, isFalse);
      expect(noSched.shifts.isEmpty, isTrue);

      final hasSched = MyShiftsResponse.fromJson(const {
        'has_published_schedule': true,
        'schedule_id': 'sched-1',
        'station_id': 'sta-1',
        'station_name': 'תחנת יילו כורדני',
        'week_start_date': '2026-09-06',
        'published_at': '2026-09-05T12:00:00Z',
        'shifts': [
          {
            'assignment_id': 'asgn-1',
            'shift_id': 'shift-1',
            'station_id': 'sta-1',
            'station_name': 'תחנת יילו כורדני',
            'operational_date': '2026-09-06',
            'shift_name': 'משמרת בוקר',
            'start_time': '07:00',
            'end_time': '15:00',
            'starts_at': '2026-09-06T04:00:00Z',
            'ends_at': '2026-09-06T12:00:00Z',
            'is_cross_midnight': false,
            'coworkers': [
              {
                'assignment_id': 'asgn-2',
                'user_id': 'user-2',
                'first_name': 'יוסי',
                'last_name': 'כהן',
                'employee_code': 'EMP-02',
              }
            ],
          }
        ],
      });
      expect(hasSched.hasPublishedSchedule, isTrue);
      expect(hasSched.shifts.length, equals(1));
      expect(hasSched.shifts.first.shiftName, equals('משמרת בוקר'));
    });
  });

  group('Phase 3 Responsive Viewport & Widget Matrix Tests', () {
    const viewports = [
      Size(320, 568),
      Size(360, 640),
      Size(375, 667),
      Size(390, 844),
      Size(430, 932),
      Size(600, 960),
      Size(768, 1024),
      Size(820, 1180),
      Size(1024, 768),
      Size(1440, 900),
      Size(1600, 1000),
    ];

    for (final size in viewports) {
      testWidgets('ShiftCard renders cleanly at ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final shift = WorkScheduleShift(
          id: 'shift-1',
          workScheduleId: 'sched-1',
          stationId: 'sta-1',
          operationalDate: DateTime(2026, 9, 6),
          periodShiftTemplateId: 'tmpl-1',
          shiftName: 'משמרת בוקר',
          startTime: '07:00',
          endTime: '15:00',
          startsAt: DateTime(2026, 9, 6, 7, 0),
          endsAt: DateTime(2026, 9, 6, 15, 0),
          requiredStaffCount: 2,
          assignedStaffCount: 1,
          sortOrder: 0,
          assignments: [
            ShiftAssignment(
              id: 'asgn-1',
              membershipId: 'mem-1',
              userId: 'usr-1',
              firstName: 'אנס',
              lastName: 'מנהל',
              role: 'ADMIN',
              availabilityStateSnapshot: 'AVAILABLE',
              availabilityOverride: false,
              assignedBy: 'usr-1',
              createdAt: DateTime.now(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ShiftCard(
                  shift: shift,
                  currentScheduleVersion: 1,
                  isPublished: false,
                ),
              ),
            ),
          ),
        );

        expect(find.text('משמרת בוקר'), findsOneWidget);
        expect(find.text('07:00 – 15:00'), findsOneWidget);
        expect(find.text('אנס מנהל'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'AppDayStrip renders smoothly without overflow at ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppDayStrip(
                weekStartDate: DateTime(2026, 9, 6),
                selectedDate: DateTime(2026, 9, 6),
                onDateSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('א׳'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
