import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../stations/presentation/active_station_provider.dart';
import '../../data/reports_repository.dart';
import '../../domain/models/report_export_model.dart';

class ExportCenterState {
  final List<ReportExportItem> recentExports;
  final bool isExporting;
  final String? activeExportingType;
  final ExportGenerationResult? lastResult;
  final String? errorMessage;

  const ExportCenterState({
    this.recentExports = const [],
    this.isExporting = false,
    this.activeExportingType,
    this.lastResult,
    this.errorMessage,
  });

  ExportCenterState copyWith({
    List<ReportExportItem>? recentExports,
    bool? isExporting,
    String? activeExportingType,
    ExportGenerationResult? lastResult,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExportCenterState(
      recentExports: recentExports ?? this.recentExports,
      isExporting: isExporting ?? this.isExporting,
      activeExportingType: activeExportingType ?? this.activeExportingType,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExportCenterNotifier
    extends StateNotifier<AsyncValue<ExportCenterState>> {
  final ReportsRepository _repository;
  final String? _activeStationId;

  ExportCenterNotifier(this._repository, this._activeStationId)
      : super(const AsyncValue.loading()) {
    loadExports();
  }

  Future<void> loadExports() async {
    try {
      final items =
          await _repository.getRecentExports(stationId: _activeStationId);
      state = AsyncValue.data(
        state.value?.copyWith(recentExports: items, clearError: true) ??
            ExportCenterState(recentExports: items),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ExportGenerationResult?> requestAndGenerateExport({
    required ReportExportType exportType,
    ExportFormat format = ExportFormat.csv,
    DateTime? from,
    DateTime? to,
  }) async {
    final current = state.value ?? const ExportCenterState();
    state = AsyncValue.data(current.copyWith(
      isExporting: true,
      activeExportingType: exportType.value,
      clearError: true,
    ));

    try {
      final filterPayload = <String, dynamic>{};
      if (from != null) {
        filterPayload['from_date'] = ReportsRepository.formatDate(from);
      }
      if (to != null) {
        filterPayload['to_date'] = ReportsRepository.formatDate(to);
      }

      final exportId = await _repository.requestExport(
        stationId: _activeStationId,
        exportType: exportType,
        format: format,
        filterPayload: filterPayload,
      );

      final result = await _repository.generateExport(exportId: exportId);

      // Auto-launch signed download URL if available
      if (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) {
        final uri = Uri.tryParse(result.downloadUrl!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      await loadExports();

      final updated = state.value ?? const ExportCenterState();
      state = AsyncValue.data(updated.copyWith(
        isExporting: false,
        activeExportingType: null,
        lastResult: result,
      ));

      return result;
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString();
      final updated = state.value ?? const ExportCenterState();
      state = AsyncValue.data(updated.copyWith(
        isExporting: false,
        activeExportingType: null,
        errorMessage: msg,
      ));
      return null;
    }
  }

  Future<void> downloadExistingExport(String exportId) async {
    final current = state.value ?? const ExportCenterState();
    state =
        AsyncValue.data(current.copyWith(isExporting: true, clearError: true));

    try {
      final result = await _repository.generateExport(exportId: exportId);
      if (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) {
        final uri = Uri.tryParse(result.downloadUrl!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      final updated = state.value ?? const ExportCenterState();
      state = AsyncValue.data(updated.copyWith(
        isExporting: false,
        lastResult: result,
      ));
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString();
      final updated = state.value ?? const ExportCenterState();
      state = AsyncValue.data(updated.copyWith(
        isExporting: false,
        errorMessage: msg,
      ));
    }
  }
}

final exportCenterControllerProvider =
    StateNotifierProvider<ExportCenterNotifier, AsyncValue<ExportCenterState>>(
        (ref) {
  final repository = ref.watch(reportsRepositoryProvider);
  final activeStationId = ref.watch(activeStationIdProvider);
  return ExportCenterNotifier(repository, activeStationId);
});
