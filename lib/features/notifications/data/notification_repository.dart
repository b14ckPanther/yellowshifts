import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/notification_item.dart';
import '../domain/models/notification_preferences.dart';
import '../domain/models/unread_count_summary.dart';

class NotificationPageResult {
  final List<NotificationItem> items;
  final bool hasMore;
  final DateTime? nextCursorCreatedAt;
  final String? nextCursorId;

  const NotificationPageResult({
    required this.items,
    required this.hasMore,
    this.nextCursorCreatedAt,
    this.nextCursorId,
  });
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationRepository {
  final SupabaseClient? _customClient;

  NotificationRepository({SupabaseClient? supabase}) : _customClient = supabase;

  SupabaseClient get _supabase {
    final custom = _customClient;
    if (custom != null) return custom;
    return Supabase.instance.client;
  }

  /// Fetch inbox with keyset pagination
  Future<NotificationPageResult> getMyNotifications({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    NotificationCategory? category,
    bool unreadOnly = false,
  }) async {
    final params = <String, dynamic>{
      'p_limit': limit,
      'p_unread_only': unreadOnly,
    };
    if (cursorCreatedAt != null) {
      params['p_cursor_created_at'] = cursorCreatedAt.toUtc().toIso8601String();
    }
    if (cursorId != null) {
      params['p_cursor_id'] = cursorId;
    }
    if (category != null) {
      params['p_category'] = category.toDbValue();
    }

    final response = await _supabase.rpc(
      'get_my_notifications',
      params: params,
    );

    if (response == null || response is! Map) {
      return const NotificationPageResult(items: [], hasMore: false);
    }

    final map = Map<String, dynamic>.from(response);
    final rawItems = map['items'] as List? ?? [];
    final items = rawItems
        .map((e) =>
            NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    DateTime? nextCursorTime;
    if (map['next_cursor_created_at'] != null) {
      nextCursorTime =
          DateTime.tryParse(map['next_cursor_created_at'] as String);
    }

    return NotificationPageResult(
      items: items,
      hasMore: map['has_more'] as bool? ?? false,
      nextCursorCreatedAt: nextCursorTime,
      nextCursorId: map['next_cursor_id'] as String?,
    );
  }

  /// Get real-time unread & critical counts for badges
  Future<UnreadCountSummary> getUnreadCount() async {
    final response = await _supabase.rpc('get_unread_notification_count');
    if (response == null || response is! Map) {
      return UnreadCountSummary.zero();
    }
    return UnreadCountSummary.fromJson(Map<String, dynamic>.from(response));
  }

  /// Mark single notification as read
  Future<void> markNotificationRead(String notificationId) async {
    await _supabase.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  /// Mark all notifications as read (optionally category scoped)
  Future<int> markAllNotificationsRead({NotificationCategory? category}) async {
    final params = <String, dynamic>{};
    if (category != null) {
      params['p_category'] = category.toDbValue();
    }

    final response = await _supabase.rpc(
      'mark_all_notifications_read',
      params: params,
    );

    if (response != null && response is Map) {
      return (response['marked_read_count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Fetch notification preferences matrix
  Future<NotificationPreferences> getPreferences() async {
    final response = await _supabase.rpc('get_my_notification_preferences');
    if (response == null || response is! Map) {
      return NotificationPreferences.defaults();
    }
    final rawPrefs = response['preferences'] as List? ?? [];
    if (rawPrefs.isEmpty) {
      return NotificationPreferences.defaults();
    }
    return NotificationPreferences.fromJsonList(rawPrefs);
  }

  /// Update channel preferences for a category
  Future<void> updatePreferences({
    required NotificationCategory category,
    required bool inApp,
    required bool push,
    required bool email,
    required bool sms,
  }) async {
    await _supabase.rpc(
      'update_my_notification_preferences',
      params: {
        'p_category': category.toDbValue(),
        'p_in_app_enabled': inApp,
        'p_push_enabled': push,
        'p_email_enabled': email,
        'p_sms_enabled': sms,
      },
    );
  }

  /// Register push token device
  Future<String?> registerDevice({
    required String platform,
    required String provider,
    required String deviceToken,
    String deviceLabel = 'Device',
  }) async {
    final response = await _supabase.rpc(
      'register_notification_device',
      params: {
        'p_platform': platform,
        'p_provider': provider,
        'p_device_token': deviceToken,
        'p_device_label': deviceLabel,
      },
    );
    if (response != null && response is Map) {
      return response['device_id'] as String?;
    }
    return null;
  }

  /// Revoke push device
  Future<void> revokeDevice(String deviceId) async {
    await _supabase.rpc(
      'revoke_notification_device',
      params: {'p_device_id': deviceId},
    );
  }

  /// Supabase Realtime channel stream for real-time notification delivery
  RealtimeChannel? subscribeToMyNotifications({
    required String userId,
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    try {
      final channel = _supabase.channel('public:notifications:$userId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_user_id',
              value: userId,
            ),
            callback: (payload) => onInsert(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_user_id',
              value: userId,
            ),
            callback: (payload) => onUpdate(payload.newRecord),
          )
          .subscribe();

      return channel;
    } catch (_) {
      return null;
    }
  }
}
