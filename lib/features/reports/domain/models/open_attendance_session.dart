class OpenAttendanceSession {
  final String id;
  final String stationId;
  final String stationName;
  final DateTime checkInTime;
  final String? shiftNameSnapshot;
  final DateTime? scheduledStartAtSnapshot;
  final DateTime? scheduledEndAtSnapshot;
  final int elapsedMinutes;
  final bool needsAttention;

  const OpenAttendanceSession({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.checkInTime,
    this.shiftNameSnapshot,
    this.scheduledStartAtSnapshot,
    this.scheduledEndAtSnapshot,
    required this.elapsedMinutes,
    required this.needsAttention,
  });

  factory OpenAttendanceSession.fromJson(Map<String, dynamic> json) {
    return OpenAttendanceSession(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String? ?? '',
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      shiftNameSnapshot: json['shift_name_snapshot'] as String?,
      scheduledStartAtSnapshot: json['scheduled_start_at_snapshot'] != null
          ? DateTime.parse(json['scheduled_start_at_snapshot'] as String)
          : null,
      scheduledEndAtSnapshot: json['scheduled_end_at_snapshot'] != null
          ? DateTime.parse(json['scheduled_end_at_snapshot'] as String)
          : null,
      elapsedMinutes: (json['elapsed_minutes'] as num?)?.toInt() ?? 0,
      needsAttention: json['needs_attention'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'station_name': stationName,
        'check_in_time': checkInTime.toIso8601String(),
        'shift_name_snapshot': shiftNameSnapshot,
        'scheduled_start_at_snapshot':
            scheduledStartAtSnapshot?.toIso8601String(),
        'scheduled_end_at_snapshot': scheduledEndAtSnapshot?.toIso8601String(),
        'elapsed_minutes': elapsedMinutes,
        'needs_attention': needsAttention,
      };
}
