import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/auth/auth_state_provider.dart';
import '../../data/notification_repository.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/models/unread_count_summary.dart';

// --- Unread Count State Provider ---
final unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, UnreadCountSummary>(() {
  return UnreadCountNotifier();
});

class UnreadCountNotifier extends AsyncNotifier<UnreadCountSummary> {
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;

  @override
  Future<UnreadCountSummary> build() async {
    try {
      final profile = ref.watch(currentProfileProvider).value;
      if (profile == null) return UnreadCountSummary.zero();

      final repo = ref.read(notificationRepositoryProvider);

      // Setup realtime subscription
      _setupRealtime(profile.id);

      // Setup heartbeat polling fallback every 60s (skip during test runs)
      _pollingTimer?.cancel();
      final isTest =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (!isTest) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          refresh();
        });
      }

      ref.onDispose(() {
        _subscription?.unsubscribe();
        _pollingTimer?.cancel();
      });

      return await repo.getUnreadCount();
    } catch (_) {
      return UnreadCountSummary.zero();
    }
  }

  void _setupRealtime(String userId) {
    _subscription?.unsubscribe();
    final repo = ref.read(notificationRepositoryProvider);
    _subscription = repo.subscribeToMyNotifications(
      userId: userId,
      onInsert: (record) {
        refresh();
      },
      onUpdate: (record) {
        refresh();
      },
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationRepositoryProvider);
      return await repo.getUnreadCount();
    });
  }

  void decrementUnread({bool wasCritical = false}) {
    state.whenData((current) {
      state = AsyncValue.data(UnreadCountSummary(
        unreadCount: (current.unreadCount - 1).clamp(0, 99999),
        criticalCount: wasCritical
            ? (current.criticalCount - 1).clamp(0, 99999)
            : current.criticalCount,
      ));
    });
  }

  void markAllRead() {
    state = const AsyncValue.data(
        UnreadCountSummary(unreadCount: 0, criticalCount: 0));
  }
}

// --- Notifications List State & Controller ---
@immutable
class NotificationListState {
  final List<NotificationItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final NotificationCategory? selectedCategory;
  final bool unreadOnly;
  final String? error;
  final DateTime? nextCursorCreatedAt;
  final String? nextCursorId;

  const NotificationListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.selectedCategory,
    this.unreadOnly = false,
    this.error,
    this.nextCursorCreatedAt,
    this.nextCursorId,
  });

  NotificationListState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    NotificationCategory? Function()? selectedCategory,
    bool? unreadOnly,
    String? Function()? error,
    DateTime? Function()? nextCursorCreatedAt,
    String? Function()? nextCursorId,
  }) {
    return NotificationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory:
          selectedCategory != null ? selectedCategory() : this.selectedCategory,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      error: error != null ? error() : this.error,
      nextCursorCreatedAt: nextCursorCreatedAt != null
          ? nextCursorCreatedAt()
          : this.nextCursorCreatedAt,
      nextCursorId: nextCursorId != null ? nextCursorId() : this.nextCursorId,
    );
  }
}

final notificationListControllerProvider = StateNotifierProvider.autoDispose<
    NotificationListController, NotificationListState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).value;
  return NotificationListController(repo, profile?.id, ref);
});

class NotificationListController extends StateNotifier<NotificationListState> {
  final NotificationRepository _repo;
  final String? _userId;
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;

  NotificationListController(this._repo, this._userId, this._ref)
      : super(const NotificationListState(isLoading: true)) {
    loadInitial();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    if (_userId == null) return;
    _realtimeChannel = _repo.subscribeToMyNotifications(
      userId: _userId,
      onInsert: (record) {
        final item = NotificationItem.fromJson(record);
        if (_matchesFilter(item)) {
          state = state.copyWith(
            items: [item, ...state.items.where((e) => e.id != item.id)],
          );
        }
      },
      onUpdate: (record) {
        final item = NotificationItem.fromJson(record);
        state = state.copyWith(
          items: state.items.map((e) => e.id == item.id ? item : e).toList(),
        );
      },
    );
  }

  bool _matchesFilter(NotificationItem item) {
    if (state.selectedCategory != null &&
        item.category != state.selectedCategory) {
      return false;
    }
    if (state.unreadOnly && !item.isUnread) {
      return false;
    }
    return true;
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final res = await _repo.getMyNotifications(
        limit: 20,
        category: state.selectedCategory,
        unreadOnly: state.unreadOnly,
      );
      state = state.copyWith(
        items: res.items,
        isLoading: false,
        hasMore: res.hasMore,
        nextCursorCreatedAt: () => res.nextCursorCreatedAt,
        nextCursorId: () => res.nextCursorId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    if (state.nextCursorCreatedAt == null || state.nextCursorId == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _repo.getMyNotifications(
        limit: 20,
        cursorCreatedAt: state.nextCursorCreatedAt,
        cursorId: state.nextCursorId,
        category: state.selectedCategory,
        unreadOnly: state.unreadOnly,
      );
      final existingIds = state.items.map((e) => e.id).toSet();
      final newUniqueItems =
          res.items.where((e) => !existingIds.contains(e.id)).toList();
      state = state.copyWith(
        items: [...state.items, ...newUniqueItems],
        isLoadingMore: false,
        hasMore: res.hasMore,
        nextCursorCreatedAt: () => res.nextCursorCreatedAt,
        nextCursorId: () => res.nextCursorId,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setCategory(NotificationCategory? category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(
      selectedCategory: () => category,
    );
    loadInitial();
  }

  void setUnreadOnly(bool unreadOnly) {
    if (state.unreadOnly == unreadOnly) return;
    state = state.copyWith(unreadOnly: unreadOnly);
    loadInitial();
  }

  Future<void> markAsRead(NotificationItem item) async {
    if (!item.isUnread) return;

    // Optimistic local update
    final now = DateTime.now();
    state = state.copyWith(
      items: state.items
          .map((e) => e.id == item.id ? e.copyWith(readAt: now) : e)
          .toList(),
    );
    _ref
        .read(unreadNotificationCountProvider.notifier)
        .decrementUnread(wasCritical: item.isCritical);

    try {
      await _repo.markNotificationRead(item.id);
    } catch (e) {
      // Revert if error
      state = state.copyWith(
        items: state.items
            .map((e) => e.id == item.id ? e.copyWith(readAt: null) : e)
            .toList(),
      );
      _ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }

  Future<void> markAllAsRead() async {
    final prevItems = state.items;
    final now = DateTime.now();

    // Optimistic update
    state = state.copyWith(
      items: state.items.map((e) => e.copyWith(readAt: now)).toList(),
    );
    _ref.read(unreadNotificationCountProvider.notifier).markAllRead();

    try {
      await _repo.markAllNotificationsRead(category: state.selectedCategory);
    } catch (e) {
      state = state.copyWith(items: prevItems);
      _ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

// --- Notification Preferences Controller ---
final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getPreferences();
});
