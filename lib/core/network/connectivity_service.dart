import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../errors/app_failure.dart';
import '../observability/app_logger.dart';

enum NetworkConnectionState {
  online,
  degraded,
  reconnecting,
  offline;

  bool get isOnline => this == NetworkConnectionState.online;
  bool get isOffline => this == NetworkConnectionState.offline;
  bool get isDegraded => this == NetworkConnectionState.degraded;
  bool get isReconnecting => this == NetworkConnectionState.reconnecting;
}

class ConnectivityNotifier extends StateNotifier<NetworkConnectionState> {
  Timer? _heartbeatTimer;

  ConnectivityNotifier() : super(NetworkConnectionState.online) {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    // Periodic heartbeat to monitor connectivity
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkHealth();
    });
  }

  Future<void> _checkHealth() async {
    // In production web/mobile, can ping health RPC or detect offline
    // If state was offline and comes back, transition through reconnecting -> online
    if (state == NetworkConnectionState.offline) {
      state = NetworkConnectionState.reconnecting;
      await Future.delayed(const Duration(milliseconds: 500));
      state = NetworkConnectionState.online;
      AppLogger.info('Network connectivity restored to ONLINE', 'Connectivity');
    }
  }

  void setOffline() {
    if (state != NetworkConnectionState.offline) {
      state = NetworkConnectionState.offline;
      AppLogger.warning('Network connectivity lost. Switched to OFFLINE mode.',
          'Connectivity');
    }
  }

  void setOnline() {
    if (state != NetworkConnectionState.online) {
      state = NetworkConnectionState.online;
      AppLogger.info(
          'Network connectivity restored to ONLINE.', 'Connectivity');
    }
  }

  void setDegraded() {
    if (state != NetworkConnectionState.degraded) {
      state = NetworkConnectionState.degraded;
      AppLogger.warning('Network connectivity is DEGRADED.', 'Connectivity');
    }
  }

  /// Guards critical mutations. Throws [NetworkFailure] if current state is offline.
  void assertOnline() {
    if (state == NetworkConnectionState.offline) {
      throw const NetworkFailure(
        'Active internet connection is required to complete this action.',
        code: 'OFFLINE_BLOCKED',
      );
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, NetworkConnectionState>((ref) {
  return ConnectivityNotifier();
});
