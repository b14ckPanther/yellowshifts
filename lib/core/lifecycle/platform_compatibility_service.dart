import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../observability/app_logger.dart';
import 'semantic_version.dart';

const String kAppClientVersion = '1.0.5';
const String kTargetSchemaVersion = '20260825000019';

enum CompatibilityStatus {
  compatible,
  clientUpdateRequired,
  schemaIncompatible,
  serverUnavailable,
  unknown;

  bool get isCompatible => this == CompatibilityStatus.compatible;
}

class PlatformCompatibilityResult {
  final CompatibilityStatus status;
  final String currentClientVersion;
  final String? minCompatibleClientVersion;
  final String? serverSchemaVersion;
  final String? platformStatus;
  final String? errorMessage;

  const PlatformCompatibilityResult({
    required this.status,
    required this.currentClientVersion,
    this.minCompatibleClientVersion,
    this.serverSchemaVersion,
    this.platformStatus,
    this.errorMessage,
  });

  factory PlatformCompatibilityResult.compatible() {
    return const PlatformCompatibilityResult(
      status: CompatibilityStatus.compatible,
      currentClientVersion: kAppClientVersion,
      platformStatus: 'HEALTHY',
    );
  }
}

final platformCompatibilityProvider =
    FutureProvider<PlatformCompatibilityResult>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final res = await supabase
        .rpc('get_platform_schema_version')
        .timeout(const Duration(seconds: 5));

    final map = Map<String, dynamic>.from(res as Map);
    final minClientStr =
        map['min_compatible_client_version']?.toString() ?? '1.0.0';
    final serverSchema = map['schema_version']?.toString() ?? '';
    final platformStatus = map['status']?.toString() ?? 'HEALTHY';

    final clientSemVer = SemanticVersion.parse(kAppClientVersion);
    final minCompatibleSemVer = SemanticVersion.parse(minClientStr);

    if (clientSemVer < minCompatibleSemVer) {
      AppLogger.warning(
        'Client version ($kAppClientVersion) is below server minimum ($minClientStr)',
        'Compatibility',
      );
      return PlatformCompatibilityResult(
        status: CompatibilityStatus.clientUpdateRequired,
        currentClientVersion: kAppClientVersion,
        minCompatibleClientVersion: minClientStr,
        serverSchemaVersion: serverSchema,
        platformStatus: platformStatus,
      );
    }

    return PlatformCompatibilityResult(
      status: CompatibilityStatus.compatible,
      currentClientVersion: kAppClientVersion,
      minCompatibleClientVersion: minClientStr,
      serverSchemaVersion: serverSchema,
      platformStatus: platformStatus,
    );
  } catch (e) {
    AppLogger.warning(
        'Failed to probe schema compatibility: $e', 'Compatibility');
    // Non-fatal if offline: return serverUnavailable
    return PlatformCompatibilityResult(
      status: CompatibilityStatus.serverUnavailable,
      currentClientVersion: kAppClientVersion,
      errorMessage: e.toString(),
    );
  }
});
