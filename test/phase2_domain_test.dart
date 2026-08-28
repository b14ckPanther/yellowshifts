import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/shift_templates/domain/shift_template.dart';
import 'package:yellowshifts/features/permissions/domain/shift_manager_permissions.dart';
import 'package:yellowshifts/features/availability/domain/availability_period.dart';
import 'package:yellowshifts/features/availability/domain/availability_submission.dart';
import 'package:yellowshifts/features/availability/domain/availability_matrix.dart';

void main() {
  group('Phase 2: ShiftTemplate Domain Tests', () {
    test('Calculates standard daytime shift duration', () {
      final template = ShiftTemplate(
        id: 't-1',
        stationId: 's-1',
        name: 'Morning',
        startTime: const TimeOfDay(hour: 7, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(template.isCrossMidnight, isFalse);
      expect(template.durationHours, 8.5);
      expect(template.formatTimeRange(), '07:00 – 15:30');
    });

    test('Calculates cross-midnight shift duration', () {
      final template = ShiftTemplate(
        id: 't-2',
        stationId: 's-1',
        name: 'Night Cross-Midnight',
        startTime: const TimeOfDay(hour: 22, minute: 0),
        endTime: const TimeOfDay(hour: 6, minute: 0),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(template.isCrossMidnight, isTrue);
      expect(template.durationHours, 8.0);
      expect(template.formatTimeRange(), '22:00 – 06:00');
    });

    test('JSON serialization & deserialization', () {
      final template = ShiftTemplate(
        id: 't-3',
        stationId: 's-1',
        name: 'Evening',
        code: 'EVE',
        startTime: const TimeOfDay(hour: 15, minute: 30),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        sortOrder: 1,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final json = template.toJson();
      final reconstructed = ShiftTemplate.fromJson(json);

      expect(reconstructed.id, template.id);
      expect(reconstructed.name, template.name);
      expect(reconstructed.code, 'EVE');
      expect(reconstructed.startTime.hour, 15);
      expect(reconstructed.endTime.hour, 23);
      expect(reconstructed.sortOrder, 1);
    });
  });

  group('Phase 2: ShiftManagerPermissions Domain Tests', () {
    test('Default permissions initialized correctly', () {
      const perms = ShiftManagerPermissions();
      expect(perms.shiftTemplatesManage, isFalse);
      expect(perms.availabilityPeriodCreate, isFalse);
      expect(perms.availabilityPeriodOpen, isFalse);
      expect(perms.availabilityTeamRead, isTrue);
    });

    test('copyWith and JSON parsing', () {
      const perms = ShiftManagerPermissions();
      final updated = perms.copyWith(
          shiftTemplatesManage: true, availabilityPeriodCreate: true);

      final json = updated.toJson();
      final fromJson = ShiftManagerPermissions.fromJson(json);

      expect(fromJson.shiftTemplatesManage, isTrue);
      expect(fromJson.availabilityPeriodCreate, isTrue);
      expect(fromJson.availabilityPeriodOpen, isFalse);
    });
  });

  group('Phase 2: AvailabilityPeriod & Dynamic Completeness Tests', () {
    test('Calculates dynamic required slots for 2, 3, and 4 shift templates',
        () {
      const t1 = PeriodShiftTemplateSnapshot(
        id: 'st-1',
        name: 'Morning',
        startTime: TimeOfDay(hour: 7, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 0),
        sortOrder: 0,
      );
      const t2 = PeriodShiftTemplateSnapshot(
        id: 'st-2',
        name: 'Evening',
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 0),
        sortOrder: 1,
      );
      const t3 = PeriodShiftTemplateSnapshot(
        id: 'st-3',
        name: 'Night',
        startTime: TimeOfDay(hour: 23, minute: 0),
        endTime: TimeOfDay(hour: 7, minute: 0),
        sortOrder: 2,
      );
      const t4 = PeriodShiftTemplateSnapshot(
        id: 'st-4',
        name: 'Split',
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 19, minute: 0),
        sortOrder: 3,
      );

      final p2 = AvailabilityPeriod(
        id: 'p-2',
        stationId: 's-1',
        weekStartDate: DateTime(2026, 9, 6),
        status: AvailabilityPeriodStatus.open,
        submissionDeadline: DateTime(2026, 9, 5),
        templates: [t1, t2],
      );
      expect(p2.requiredSlotCount, 14); // 2 * 7 = 14
      expect(p2.operationalDays.length, 7);

      final p3 = AvailabilityPeriod(
        id: 'p-3',
        stationId: 's-1',
        weekStartDate: DateTime(2026, 9, 6),
        status: AvailabilityPeriodStatus.open,
        submissionDeadline: DateTime(2026, 9, 5),
        templates: [t1, t2, t3],
      );
      expect(p3.requiredSlotCount, 21); // 3 * 7 = 21

      final p4 = AvailabilityPeriod(
        id: 'p-4',
        stationId: 's-1',
        weekStartDate: DateTime(2026, 9, 6),
        status: AvailabilityPeriodStatus.open,
        submissionDeadline: DateTime(2026, 9, 5),
        templates: [t1, t2, t3, t4],
      );
      expect(p4.requiredSlotCount, 28); // 4 * 7 = 28
    });
  });

  group('Phase 2: EmployeeAvailabilitySubmission & Slot Key Tests', () {
    test('Slot key formatting and 3-state retrieval', () {
      final date = DateTime(2026, 9, 6);
      const templateId = 'st-1';
      final key = makeSlotKey(date, templateId);
      expect(key, '2026-09-06_st-1');

      final submission = EmployeeAvailabilitySubmission(
        periodId: 'p-1',
        stationId: 's-1',
        weekStartDate: date,
        periodStatus: 'OPEN',
        submissionDeadline: DateTime(2026, 9, 5),
        submissionStatus: AvailabilitySubmissionStatus.draft,
        entries: {
          '2026-09-06_st-1': true,
          '2026-09-06_st-2': false,
        },
      );

      expect(submission.getSlotState(date, 'st-1'), isTrue);
      expect(submission.getSlotState(date, 'st-2'), isFalse);
      expect(submission.getSlotState(date, 'st-3'), isNull); // Unanswered
      expect(submission.answeredCount, 2);
    });
  });

  group('Phase 2: Manager Availability KPI Invariant Tests', () {
    test('KPI mathematical invariants hold', () {
      const kpis = AvailabilityKpiMetrics(
        eligibleEmployees: 25,
        submittedEmployees: 18,
        draftEmployees: 4,
        notStartedEmployees: 3,
        notSubmittedEmployees: 7,
      );

      // Invariant 1: eligible = submitted + draft + notStarted
      expect(
        kpis.eligibleEmployees,
        kpis.submittedEmployees +
            kpis.draftEmployees +
            kpis.notStartedEmployees,
      );

      // Invariant 2: notSubmitted = draft + notStarted
      expect(
        kpis.notSubmittedEmployees,
        kpis.draftEmployees + kpis.notStartedEmployees,
      );

      expect(kpis.submissionRate, 18 / 25);
    });
  });
}
