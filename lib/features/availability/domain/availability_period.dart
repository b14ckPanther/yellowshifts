import 'package:flutter/material.dart';

enum AvailabilityPeriodStatus {
  draft,
  open,
  closed;

  static AvailabilityPeriodStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'OPEN':
        return AvailabilityPeriodStatus.open;
      case 'CLOSED':
        return AvailabilityPeriodStatus.closed;
      case 'DRAFT':
      default:
        return AvailabilityPeriodStatus.draft;
    }
  }

  String toDbValue() => name.toUpperCase();
}

/// Frozen snapshot of shift template used in a specific availability period
class PeriodShiftTemplateSnapshot {
  final String id;
  final String name;
  final String? code;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int sortOrder;

  const PeriodShiftTemplateSnapshot({
    required this.id,
    required this.name,
    this.code,
    required this.startTime,
    required this.endTime,
    required this.sortOrder,
  });

  bool get isCrossMidnight {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return startMinutes > endMinutes;
  }

  String formatTimeRange() {
    final sH = startTime.hour.toString().padLeft(2, '0');
    final sM = startTime.minute.toString().padLeft(2, '0');
    final eH = endTime.hour.toString().padLeft(2, '0');
    final eM = endTime.minute.toString().padLeft(2, '0');
    return '$sH:$sM – $eH:$eM';
  }

  factory PeriodShiftTemplateSnapshot.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(dynamic timeVal) {
      if (timeVal == null) return const TimeOfDay(hour: 0, minute: 0);
      final timeStr = timeVal.toString();
      final parts = timeStr.split(':');
      final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final id =
        (json['id'] ?? json['period_shift_template_id'] ?? '').toString();
    final name = (json['name_snapshot'] ?? json['name'] ?? 'Shift').toString();
    final code = (json['code_snapshot'] ?? json['code'])?.toString();
    final startTimeRaw = json['start_time_snapshot'] ?? json['start_time'];
    final endTimeRaw = json['end_time_snapshot'] ?? json['end_time'];
    final sortOrder =
        (json['sort_order_snapshot'] ?? json['sort_order'] as num?)?.toInt() ??
            0;

    return PeriodShiftTemplateSnapshot(
      id: id,
      name: name,
      code: code,
      startTime: parseTime(startTimeRaw),
      endTime: parseTime(endTimeRaw),
      sortOrder: sortOrder,
    );
  }
}

/// Domain entity for Weekly Availability Period
class AvailabilityPeriod {
  final String id;
  final String stationId;
  final DateTime weekStartDate;
  final AvailabilityPeriodStatus status;
  final DateTime submissionDeadline;
  final String? notes;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final List<PeriodShiftTemplateSnapshot> templates;

  const AvailabilityPeriod({
    required this.id,
    required this.stationId,
    required this.weekStartDate,
    required this.status,
    required this.submissionDeadline,
    this.notes,
    this.openedAt,
    this.closedAt,
    this.templates = const [],
  });

  bool get isOpen => status == AvailabilityPeriodStatus.open;
  bool get isClosed => status == AvailabilityPeriodStatus.closed;
  bool get isDraft => status == AvailabilityPeriodStatus.draft;

  /// Operational week end date (7 days from start)
  DateTime get weekEndDate => weekStartDate.add(const Duration(days: 6));

  /// List of 7 operational calendar dates
  List<DateTime> get operationalDays {
    return List.generate(
        7, (index) => weekStartDate.add(Duration(days: index)));
  }

  /// Total required answer slots for completeness (templates x 7 days)
  int get requiredSlotCount => templates.length * 7;

  factory AvailabilityPeriod.fromJson(Map<String, dynamic> json) {
    final templatesRaw = json['templates'] as List? ?? [];
    return AvailabilityPeriod(
      id: (json['id'] ?? '').toString(),
      stationId: (json['station_id'] ?? '').toString(),
      weekStartDate: json['week_start_date'] != null
          ? DateTime.parse(json['week_start_date'].toString())
          : DateTime.now(),
      status: AvailabilityPeriodStatus.fromString(
          (json['status'] ?? 'DRAFT').toString()),
      submissionDeadline: json['submission_deadline'] != null
          ? DateTime.parse(json['submission_deadline'].toString())
          : DateTime.now().add(const Duration(days: 5)),
      notes: json['notes']?.toString(),
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'].toString())
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'].toString())
          : null,
      templates: templatesRaw
          .whereType<Map>()
          .map((t) => PeriodShiftTemplateSnapshot.fromJson(
              Map<String, dynamic>.from(t)))
          .toList(),
    );
  }
}
