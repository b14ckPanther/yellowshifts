import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/features/notifications/domain/models/notification_item.dart';
import 'package:yellowshifts/features/notifications/domain/models/notification_preferences.dart';
import 'package:yellowshifts/features/notifications/domain/models/notification_device.dart';
import 'package:yellowshifts/features/notifications/domain/models/unread_count_summary.dart';

void main() {
  group('NotificationCategory & NotificationPriority Enum Tests', () {
    test('parses all category enum strings correctly and case-insensitively',
        () {
      expect(NotificationCategory.fromString('SCHEDULE'),
          equals(NotificationCategory.schedule));
      expect(NotificationCategory.fromString('attendance'),
          equals(NotificationCategory.attendance));
      expect(NotificationCategory.fromString('AVAILABILITY'),
          equals(NotificationCategory.availability));
      expect(NotificationCategory.fromString('operations'),
          equals(NotificationCategory.operations));
      expect(NotificationCategory.fromString('SYSTEM'),
          equals(NotificationCategory.system));
      expect(NotificationCategory.fromString('UNKNOWN_RANDOM'),
          equals(NotificationCategory.system));

      expect(NotificationCategory.schedule.toDbValue(), equals('SCHEDULE'));
      expect(NotificationCategory.attendance.toDbValue(), equals('ATTENDANCE'));
      expect(NotificationCategory.availability.toDbValue(),
          equals('AVAILABILITY'));
      expect(NotificationCategory.operations.toDbValue(), equals('OPERATIONS'));
      expect(NotificationCategory.system.toDbValue(), equals('SYSTEM'));
    });

    test('parses all priority enum strings correctly', () {
      expect(NotificationPriority.fromString('LOW'),
          equals(NotificationPriority.low));
      expect(NotificationPriority.fromString('normal'),
          equals(NotificationPriority.normal));
      expect(NotificationPriority.fromString('HIGH'),
          equals(NotificationPriority.high));
      expect(NotificationPriority.fromString('critical'),
          equals(NotificationPriority.critical));
      expect(NotificationPriority.fromString('unknown'),
          equals(NotificationPriority.normal));

      expect(NotificationPriority.critical.toDbValue(), equals('CRITICAL'));
      expect(NotificationPriority.high.toDbValue(), equals('HIGH'));
    });
  });

  group('NotificationItem Model Tests', () {
    test('parses full JSON payload with render_data and action_data', () {
      final json = {
        'id': '11111111-2222-3333-4444-555555555555',
        'station_id': '99999999-8888-7777-6666-555555555555',
        'category': 'SCHEDULE',
        'event_type': 'SCHEDULE_PUBLISHED',
        'priority': 'NORMAL',
        'title_key': 'notif_schedule_published_title',
        'body_key': 'notif_schedule_published_body',
        'render_data': {
          'station_name': 'תחנת יילו כורדני',
          'week_start_date': '2026-08-30',
          'version': 2,
        },
        'action_type': 'NAVIGATE_SCHEDULE',
        'action_data': {
          'schedule_id': '88888888-8888-8888-8888-888888888888',
        },
        'is_mandatory': false,
        'read_at': null,
        'seen_at': null,
        'created_at': '2026-08-26T10:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, equals('11111111-2222-3333-4444-555555555555'));
      expect(item.stationId, equals('99999999-8888-7777-6666-555555555555'));
      expect(item.category, equals(NotificationCategory.schedule));
      expect(item.eventType, equals('SCHEDULE_PUBLISHED'));
      expect(item.priority, equals(NotificationPriority.normal));
      expect(item.titleKey, equals('notif_schedule_published_title'));
      expect(item.bodyKey, equals('notif_schedule_published_body'));
      expect(item.renderData['station_name'], equals('תחנת יילו כורדני'));
      expect(item.actionType, equals('NAVIGATE_SCHEDULE'));
      expect(item.isMandatory, isFalse);
      expect(item.isUnread, isTrue);
      expect(item.isCritical, isFalse);
    });

    test('copyWith updates read status immutably', () {
      final item = NotificationItem(
        id: 'test-1',
        category: NotificationCategory.attendance,
        eventType: 'EMPLOYEE_LATE',
        priority: NotificationPriority.high,
        titleKey: 'notif_emp_late_title',
        bodyKey: 'notif_emp_late_body',
        renderData: const {},
        actionData: const {},
        isMandatory: false,
        readAt: null,
        createdAt: DateTime.now(),
      );

      expect(item.isUnread, isTrue);
      final readNow = DateTime.now();
      final updated = item.copyWith(readAt: readNow);
      expect(updated.isUnread, isFalse);
      expect(updated.readAt, equals(readNow));
      expect(item.isUnread, isTrue); // original intact
    });
  });

  group('NotificationPreferences Model Tests', () {
    test('defaults generate all 5 categories with in-app and push enabled', () {
      final defaults = NotificationPreferences.defaults();
      expect(defaults.preferences.length, equals(5));

      for (final cat in NotificationCategory.values) {
        final pref = defaults.forCategory(cat);
        expect(pref, isNotNull);
        expect(pref!.inAppEnabled, isTrue);
        expect(pref.pushEnabled, isTrue);
        expect(pref.emailEnabled, isFalse);
        expect(pref.smsEnabled, isFalse);
      }
    });

    test('parses from RPC JSON list', () {
      final list = [
        {
          'category': 'OPERATIONS',
          'in_app_enabled': true,
          'push_enabled': true,
          'email_enabled': true,
          'sms_enabled': false,
        },
        {
          'category': 'SYSTEM',
          'in_app_enabled': true,
          'push_enabled': false,
          'email_enabled': false,
          'sms_enabled': true,
        },
      ];

      final prefs = NotificationPreferences.fromJsonList(list);
      final ops = prefs.forCategory(NotificationCategory.operations);
      expect(ops, isNotNull);
      expect(ops!.emailEnabled, isTrue);

      final sys = prefs.forCategory(NotificationCategory.system);
      expect(sys, isNotNull);
      expect(sys!.smsEnabled, isTrue);
      expect(sys.pushEnabled, isFalse);
    });
  });

  group('UnreadCountSummary & NotificationDevice Tests', () {
    test('UnreadCountSummary calculates hasUnread and hasCritical', () {
      final zero = UnreadCountSummary.zero();
      expect(zero.hasUnread, isFalse);
      expect(zero.hasCritical, isFalse);

      final withUnread = UnreadCountSummary.fromJson(const {
        'unread_count': 5,
        'critical_count': 0,
      });
      expect(withUnread.hasUnread, isTrue);
      expect(withUnread.hasCritical, isFalse);

      final withCritical = UnreadCountSummary.fromJson(const {
        'unread_count': 2,
        'critical_count': 1,
      });
      expect(withCritical.hasUnread, isTrue);
      expect(withCritical.hasCritical, isTrue);
    });

    test('NotificationDevice parses device registration record', () {
      final json = {
        'id': 'device-123',
        'platform': 'ios',
        'provider': 'apns',
        'device_label': 'iPhone 15 Pro',
        'is_active': true,
        'last_seen_at': '2026-08-26T12:00:00.000Z',
        'created_at': '2026-08-25T12:00:00.000Z',
        'revoked_at': null,
      };

      final device = NotificationDevice.fromJson(json);
      expect(device.id, equals('device-123'));
      expect(device.platform, equals('ios'));
      expect(device.provider, equals('apns'));
      expect(device.deviceLabel, equals('iPhone 15 Pro'));
      expect(device.isActive, isTrue);
      expect(device.revokedAt, isNull);
    });
  });
}
