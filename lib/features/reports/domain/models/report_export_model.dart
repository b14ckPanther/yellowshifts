import 'package:flutter/foundation.dart';

enum ReportExportType {
  myAttendanceHistory('MY_ATTENDANCE_HISTORY'),
  stationAttendanceSummary('STATION_ATTENDANCE_SUMMARY'),
  stationEmployeeWorkedHours('STATION_EMPLOYEE_WORKED_HOURS'),
  dailyAttendanceReport('DAILY_ATTENDANCE_REPORT'),
  attendanceCorrectionLedger('ATTENDANCE_CORRECTION_LEDGER'),
  publishedSchedule('PUBLISHED_SCHEDULE'),
  employeeDirectory('EMPLOYEE_DIRECTORY'),
  availabilityOverview('AVAILABILITY_OVERVIEW');

  final String value;
  const ReportExportType(this.value);

  static ReportExportType fromValue(String value) {
    return ReportExportType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportExportType.myAttendanceHistory,
    );
  }
}

enum ExportFormat {
  csv('CSV'),
  pdf('PDF');

  final String value;
  const ExportFormat(this.value);

  static ExportFormat fromValue(String value) {
    return ExportFormat.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExportFormat.csv,
    );
  }
}

enum ExportStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  failed('FAILED'),
  expired('EXPIRED');

  final String value;
  const ExportStatus(this.value);

  static ExportStatus fromValue(String value) {
    return ExportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExportStatus.pending,
    );
  }

  bool get isCompleted => this == ExportStatus.completed;
  bool get isExpired => this == ExportStatus.expired;
  bool get isFailed => this == ExportStatus.failed;
  bool get isPendingOrProcessing =>
      this == ExportStatus.pending || this == ExportStatus.processing;
}

@immutable
class ReportExportItem {
  final String id;
  final String? stationId;
  final String requestedBy;
  final ReportExportType exportType;
  final ExportFormat format;
  final ExportStatus status;
  final Map<String, dynamic> filterPayload;
  final String? storagePath;
  final int? rowCount;
  final int? fileSizeBytes;
  final String? failureCode;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime expiresAt;

  const ReportExportItem({
    required this.id,
    this.stationId,
    required this.requestedBy,
    required this.exportType,
    required this.format,
    required this.status,
    this.filterPayload = const {},
    this.storagePath,
    this.rowCount,
    this.fileSizeBytes,
    this.failureCode,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt) || status.isExpired;

  factory ReportExportItem.fromJson(Map<String, dynamic> json) {
    return ReportExportItem(
      id: json['id'] as String,
      stationId: json['station_id'] as String?,
      requestedBy: json['requested_by'] as String? ?? '',
      exportType:
          ReportExportType.fromValue(json['export_type'] as String? ?? ''),
      format: ExportFormat.fromValue(json['format'] as String? ?? 'CSV'),
      status: ExportStatus.fromValue(json['status'] as String? ?? 'PENDING'),
      filterPayload: (json['filter_payload'] as Map<String, dynamic>?) ?? {},
      storagePath: json['storage_path'] as String?,
      rowCount: (json['row_count'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      failureCode: json['failure_code'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

@immutable
class ExportGenerationResult {
  final bool success;
  final String exportId;
  final String exportType;
  final String format;
  final int rowCount;
  final int fileSizeBytes;
  final String? downloadUrl;
  final String? csvContent;
  final int expiresInSeconds;

  const ExportGenerationResult({
    required this.success,
    required this.exportId,
    required this.exportType,
    required this.format,
    required this.rowCount,
    required this.fileSizeBytes,
    this.downloadUrl,
    this.csvContent,
    this.expiresInSeconds = 900,
  });

  factory ExportGenerationResult.fromJson(Map<String, dynamic> json) {
    return ExportGenerationResult(
      success: json['success'] as bool? ?? false,
      exportId: json['export_id'] as String? ?? '',
      exportType: json['export_type'] as String? ?? '',
      format: json['format'] as String? ?? 'CSV',
      rowCount: (json['row_count'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String?,
      csvContent: json['csv_content'] as String?,
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 900,
    );
  }
}
