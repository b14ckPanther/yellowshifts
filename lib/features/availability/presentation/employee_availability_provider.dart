import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../data/availability_repository.dart';
import '../domain/availability_period.dart';
import '../domain/availability_submission.dart';
import 'active_period_provider.dart';

class EmployeeAvailabilityState {
  final AvailabilityPeriod? period;
  final EmployeeAvailabilitySubmission? submission;
  final Map<String, bool> localEntries;
  final bool isLoading;
  final bool isSavingDraft;
  final bool isSubmitting;
  final String? errorMessage;
  final bool saveSuccess;

  const EmployeeAvailabilityState({
    this.period,
    this.submission,
    this.localEntries = const {},
    this.isLoading = false,
    this.isSavingDraft = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.saveSuccess = false,
  });

  bool? getSlotState(DateTime date, String periodShiftTemplateId) {
    final key = makeSlotKey(date, periodShiftTemplateId);
    return localEntries[key];
  }

  int get totalSlots => (period?.templates.length ?? 0) * 7;
  int get answeredSlots => localEntries.length;
  double get progress =>
      totalSlots > 0 ? (answeredSlots / totalSlots).clamp(0.0, 1.0) : 0.0;
  bool get isComplete => totalSlots > 0 && answeredSlots == totalSlots;

  EmployeeAvailabilityState copyWith({
    AvailabilityPeriod? period,
    EmployeeAvailabilitySubmission? submission,
    Map<String, bool>? localEntries,
    bool? isLoading,
    bool? isSavingDraft,
    bool? isSubmitting,
    String? errorMessage,
    bool? saveSuccess,
  }) {
    return EmployeeAvailabilityState(
      period: period ?? this.period,
      submission: submission ?? this.submission,
      localEntries: localEntries ?? this.localEntries,
      isLoading: isLoading ?? this.isLoading,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

final employeeAvailabilityProvider = StateNotifierProvider.autoDispose<
    EmployeeAvailabilityNotifier, EmployeeAvailabilityState>((ref) {
  return EmployeeAvailabilityNotifier(ref);
});

class EmployeeAvailabilityNotifier
    extends StateNotifier<EmployeeAvailabilityState> {
  final Ref _ref;
  Timer? _debounceTimer;

  EmployeeAvailabilityNotifier(this._ref)
      : super(const EmployeeAvailabilityState(isLoading: true)) {
    _initialize();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final stationId = _ref.read(activeStationIdProvider);
    if (stationId == null) {
      state = const EmployeeAvailabilityState(isLoading: false);
      return;
    }

    try {
      final repo = _ref.read(availabilityRepositoryProvider);
      final period = await repo.getCurrentAvailabilityPeriod(stationId);

      if (period == null) {
        state = const EmployeeAvailabilityState(isLoading: false);
        return;
      }

      final submission = await repo.getMySubmission(period.id);
      final entries = Map<String, bool>.from(submission?.entries ?? {});

      state = EmployeeAvailabilityState(
        period: period,
        submission: submission,
        localEntries: entries,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load availability request: $e',
      );
    }
  }

  /// Sets slot availability: true (available), false (unavailable), or removes if toggled off.
  void toggleSlot(
      DateTime date, String periodShiftTemplateId, bool isAvailable) {
    if (state.period == null || !state.period!.isOpen) return;

    final key = makeSlotKey(date, periodShiftTemplateId);
    final updated = Map<String, bool>.from(state.localEntries);

    if (updated[key] == isAvailable) {
      // Un-select if tapped again
      updated.remove(key);
    } else {
      updated[key] = isAvailable;
    }

    state = state.copyWith(localEntries: updated);

    // Debounce auto-save
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveDraft();
    });
  }

  /// Bulk action: mark entire day as available or unavailable
  void setDayAvailability(DateTime date, bool isAvailable) {
    if (state.period == null || !state.period!.isOpen) return;

    final updated = Map<String, bool>.from(state.localEntries);
    for (final template in state.period!.templates) {
      final key = makeSlotKey(date, template.id);
      updated[key] = isAvailable;
    }

    state = state.copyWith(localEntries: updated);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    final period = state.period;
    if (period == null) return;

    state = state.copyWith(isSavingDraft: true);

    try {
      final entriesList = state.localEntries.entries.map((e) {
        final parts = e.key.split('_');
        final dateStr = parts[0];
        final templateId = parts[1];
        return {
          'date': dateStr,
          'period_shift_template_id': templateId,
          'is_available': e.value,
        };
      }).toList();

      await _ref.read(availabilityRepositoryProvider).saveDraft(
            periodId: period.id,
            entries: entriesList,
          );

      state = state.copyWith(isSavingDraft: false, saveSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isSavingDraft: false,
        errorMessage: 'Auto-save failed: $e',
      );
    }
  }

  Future<bool> submit() async {
    final period = state.period;
    if (period == null || !state.isComplete) return false;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final entriesList = state.localEntries.entries.map((e) {
        final parts = e.key.split('_');
        final dateStr = parts[0];
        final templateId = parts[1];
        return {
          'date': dateStr,
          'period_shift_template_id': templateId,
          'is_available': e.value,
        };
      }).toList();

      await _ref.read(availabilityRepositoryProvider).submitAvailability(
            periodId: period.id,
            entries: entriesList,
          );

      await _initialize(); // Refresh submission status
      _ref.invalidate(currentAvailabilityPeriodProvider);

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Submission failed: $e',
      );
      return false;
    }
  }
}
