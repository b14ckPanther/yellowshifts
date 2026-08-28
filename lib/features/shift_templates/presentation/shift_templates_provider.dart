import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/shift_template_repository.dart';
import '../domain/shift_template.dart';

final shiftTemplatesProvider = AsyncNotifierProvider.autoDispose<
    ShiftTemplatesNotifier, List<ShiftTemplate>>(() {
  return ShiftTemplatesNotifier();
});

class ShiftTemplatesNotifier
    extends AutoDisposeAsyncNotifier<List<ShiftTemplate>> {
  RealtimeChannel? _subscription;

  @override
  Future<List<ShiftTemplate>> build() async {
    final stationId = ref.watch(activeStationIdProvider);
    if (stationId == null) return [];

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    _setupRealtimeSubscription(stationId);

    final repo = ref.read(shiftTemplateRepositoryProvider);
    return repo.getStationTemplates(stationId);
  }

  void _setupRealtimeSubscription(String stationId) {
    try {
      _subscription = Supabase.instance.client
          .channel('public:shift_templates:station=$stationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shift_templates',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'station_id',
              value: stationId,
            ),
            callback: (payload) {
              refresh();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> refresh() async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(shiftTemplateRepositoryProvider)
          .getStationTemplates(stationId);
    });
  }

  Future<void> createTemplate({
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
  }) async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    await ref.read(shiftTemplateRepositoryProvider).createTemplate(
          stationId: stationId,
          name: name,
          code: code,
          startTime: startTime,
          endTime: endTime,
          sortOrder: sortOrder,
        );
    await refresh();
  }

  Future<void> updateTemplate({
    required String templateId,
    required String name,
    String? code,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    await ref.read(shiftTemplateRepositoryProvider).updateTemplate(
          stationId: stationId,
          templateId: templateId,
          name: name,
          code: code,
          startTime: startTime,
          endTime: endTime,
          sortOrder: sortOrder,
          isActive: isActive,
        );
    await refresh();
  }

  Future<void> toggleTemplateActive(ShiftTemplate template) async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    if (template.isActive) {
      await ref
          .read(shiftTemplateRepositoryProvider)
          .deactivateTemplate(stationId, template.id);
    } else {
      await ref
          .read(shiftTemplateRepositoryProvider)
          .reactivateTemplate(stationId, template.id);
    }
    await refresh();
  }

  Future<void> reorderTemplates(List<String> templateIds) async {
    final stationId = ref.read(activeStationIdProvider);
    if (stationId == null) return;

    await ref
        .read(shiftTemplateRepositoryProvider)
        .reorderTemplates(stationId, templateIds);
    await refresh();
  }
}
