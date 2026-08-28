import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/config/app_config.dart';
import '../auth/auth_state_provider.dart';
import '../permissions/station_access_context.dart';
import '../../features/stations/presentation/active_station_provider.dart';
import 'platform_compatibility_service.dart';

enum StartupPhase {
  booting,
  configError,
  clientOutdated,
  schemaIncompatible,
  serverUnavailable,
  networkError,
  authLoading,
  unauthenticated,
  authenticatedLoadingStations,
  authenticatedNoMemberships,
  authenticatedStationReady,
  authenticatedStationAccessRevoked,
  offlineWithValidCache,
  fatalRecoverable,
}

class AppStartupState {
  final StartupPhase phase;
  final String? errorMessage;
  final String? minClientVersion;

  const AppStartupState({
    required this.phase,
    this.errorMessage,
    this.minClientVersion,
  });

  bool get isReady => phase == StartupPhase.authenticatedStationReady;
  bool get isLoading =>
      phase == StartupPhase.booting ||
      phase == StartupPhase.authLoading ||
      phase == StartupPhase.authenticatedLoadingStations;
  bool get hasError =>
      phase == StartupPhase.configError ||
      phase == StartupPhase.clientOutdated ||
      phase == StartupPhase.schemaIncompatible ||
      phase == StartupPhase.fatalRecoverable;
}

final appStartupStateProvider = Provider<AppStartupState>((ref) {
  // 1. Validate Environment Configuration
  try {
    AppConfig.validateConfig();
  } catch (e) {
    return AppStartupState(
      phase: StartupPhase.configError,
      errorMessage: e.toString(),
    );
  }

  // 2. Check Platform & Schema Compatibility
  final compatibilityAsync = ref.watch(platformCompatibilityProvider);
  if (compatibilityAsync.hasValue) {
    final compat = compatibilityAsync.value!;
    if (compat.status == CompatibilityStatus.clientUpdateRequired) {
      return AppStartupState(
        phase: StartupPhase.clientOutdated,
        minClientVersion: compat.minCompatibleClientVersion,
        errorMessage:
            'Client version is outdated. Minimum required: ${compat.minCompatibleClientVersion}',
      );
    }
  }

  // 3. Evaluate Auth State
  final authStateAsync = ref.watch(authStateStreamProvider);
  if (authStateAsync.isLoading && !authStateAsync.hasValue) {
    return const AppStartupState(phase: StartupPhase.authLoading);
  }

  final user = ref.watch(currentAuthUserProvider);
  if (user == null) {
    return const AppStartupState(phase: StartupPhase.unauthenticated);
  }

  // 4. Evaluate Memberships & Station Context
  final membershipsAsync = ref.watch(userMembershipsStreamProvider);
  if (membershipsAsync.isLoading && !membershipsAsync.hasValue) {
    return const AppStartupState(
      phase: StartupPhase.authenticatedLoadingStations,
    );
  }

  final memberships = membershipsAsync.value ?? [];
  if (memberships.isEmpty) {
    return const AppStartupState(
      phase: StartupPhase.authenticatedNoMemberships,
    );
  }

  final accessContext = ref.watch(stationAccessContextProvider);
  if (!accessContext.hasActiveStation) {
    return const AppStartupState(
      phase: StartupPhase.authenticatedNoMemberships,
    );
  }

  if (accessContext.isActive) {
    return const AppStartupState(
      phase: StartupPhase.authenticatedStationReady,
    );
  } else {
    return const AppStartupState(
      phase: StartupPhase.authenticatedStationAccessRevoked,
    );
  }
});
