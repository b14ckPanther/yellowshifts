import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/reports/domain/models/report_export_model.dart';
import 'package:yellowshifts/features/audit/domain/models/audit_log_entry.dart';
import 'package:yellowshifts/features/system_health/domain/models/station_system_health.dart';
import 'package:yellowshifts/features/stations/domain/station.dart';

void main() {
  group('Phase 8 ReportExportModel', () {
    test('ReportExportItem parsing and expired logic', () {
      final now = DateTime.now();
      final expiredItem = ReportExportItem(
        id: 'exp-1',
        stationId: 'st-1',
        requestedBy: 'user-1',
        exportType: ReportExportType.stationAttendanceSummary,
        format: ExportFormat.csv,
        status: ExportStatus.completed,
        storagePath: 'exports/st-1/exp-1.csv',
        fileSizeBytes: 2048,
        rowCount: 42,
        expiresAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      expect(expiredItem.isExpired, true);
      expect(expiredItem.status.isCompleted, true);

      final validItem = ReportExportItem(
        id: 'exp-2',
        stationId: 'st-1',
        requestedBy: 'user-1',
        exportType: ReportExportType.publishedSchedule,
        format: ExportFormat.pdf,
        status: ExportStatus.completed,
        storagePath: 'exports/st-1/exp-2.pdf',
        fileSizeBytes: 1048576,
        rowCount: 120,
        expiresAt: now.add(const Duration(minutes: 10)),
        createdAt: now,
      );

      expect(validItem.isExpired, false);
      expect(validItem.format, ExportFormat.pdf);
    });

    test('ReportExportItem.fromJson handles JSON properly', () {
      final map = {
        'id': 'exp-json-1',
        'station_id': 'st-1',
        'requested_by': 'user-1',
        'export_type': 'EMPLOYEE_DIRECTORY',
        'format': 'CSV',
        'status': 'COMPLETED',
        'storage_path': 'exports/st-1/exp-json-1.csv',
        'file_size_bytes': 4096,
        'row_count': 55,
        'filter_payload': {'department': 'operations'},
        'expires_at': '2026-08-27T12:00:00Z',
        'created_at': '2026-08-27T11:45:00Z',
      };

      final item = ReportExportItem.fromJson(map);
      expect(item.id, 'exp-json-1');
      expect(item.exportType, ReportExportType.employeeDirectory);
      expect(item.format, ExportFormat.csv);
      expect(item.status, ExportStatus.completed);
      expect(item.rowCount, 55);
      expect(item.fileSizeBytes, 4096);
    });
  });

  group('Phase 8 AuditLogEntry', () {
    test(
        'AuditLogEntry.fromJson handles sanitized JSON metadata and profile fallbacks',
        () {
      final map = {
        'id': 'audit-1',
        'station_id': 'st-1',
        'actor_user_id': 'user-1',
        'actor_name': 'Sarah Connor',
        'actor_email': 'sarah@yellowshifts.com',
        'action': 'STATION_SETTINGS_UPDATED',
        'target_type': 'STATION',
        'target_id': 'st-1',
        'metadata': {
          'updated_fields': ['late_grace_minutes', 'check_in_early_minutes'],
          'late_grace_minutes': 10,
        },
        'created_at': '2026-08-27T10:00:00Z',
      };

      final entry = AuditLogEntry.fromJson(map);
      expect(entry.id, 'audit-1');
      expect(entry.actorName, 'Sarah Connor');
      expect(entry.actorEmail, 'sarah@yellowshifts.com');
      expect(entry.action, 'STATION_SETTINGS_UPDATED');
      expect(entry.metadata['late_grace_minutes'], 10);
      expect(entry.metadata.containsKey('password'), false);
    });
  });

  group('Phase 8 StationSystemHealth', () {
    test('StationSystemHealth anomaly detection', () {
      final now = DateTime.now();
      final healthy = StationSystemHealth(
        stationId: 'st-1',
        nfcTagsTotal: 5,
        nfcTagsActive: 5,
        exportsTotal24h: 12,
        exportsFailed24h: 0,
        staleOpenSessions: 0,
        serverTime: now,
      );

      expect(healthy.hasAnomalies, false);

      final withStale = StationSystemHealth(
        stationId: 'st-1',
        nfcTagsTotal: 5,
        nfcTagsActive: 4,
        exportsTotal24h: 12,
        exportsFailed24h: 1,
        staleOpenSessions: 2,
        serverTime: now,
      );

      expect(withStale.hasAnomalies, true);
    });
  });

  group('Phase 8 Station Model Grace Windows', () {
    test('Station defaults and custom grace windows', () {
      final now = DateTime.now();
      final defaultStation = Station(
        id: 'st-1',
        name: 'Haifa Station',
        code: 'HFA-01',
        timezone: 'Asia/Jerusalem',
        locale: 'he',
        weekStart: 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(defaultStation.lateGraceMinutes, 5);
      expect(defaultStation.checkInEarlyMinutes, 15);

      final customStation = defaultStation.copyWith(
        lateGraceMinutes: 10,
        checkInEarlyMinutes: 30,
      );

      expect(customStation.lateGraceMinutes, 10);
      expect(customStation.checkInEarlyMinutes, 30);
    });
  });
}
