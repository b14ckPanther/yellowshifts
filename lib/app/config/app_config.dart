enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromString(String env) {
    switch (env.toLowerCase()) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'development':
      case 'dev':
      default:
        return AppEnvironment.development;
    }
  }
}

class AppConfigurationException implements Exception {
  final String message;
  const AppConfigurationException(this.message);

  @override
  String toString() => 'AppConfigurationException: $message';
}

/// AppConfig provides environment-aware configuration and validation for YellowShifts.
class AppConfig {
  static const String appVersion = '1.0.5';
  static const int buildNumber = 11;
  static const String releaseIdentifier = '$appVersion+$buildNumber';
  static const String minimumBackendSchemaVersion = '20260825000019';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://khtjvkzpqwjtgpgywpcf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodGp2a3pwcXdqdGdwZ3l3cGNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NzQ4MTQsImV4cCI6MjEwMzI1MDgxNH0.DaitQ7FTIaPrsHHmfRBWBul5DPTjkD_od77EHE4T39s',
  );

  static const String environmentStr = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get environment =>
      AppEnvironment.fromString(environmentStr);

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProduction => environment == AppEnvironment.production;

  /// Validates environment configuration at startup.
  /// Throws [AppConfigurationException] if mandatory variables are missing or invalid.
  static void validateConfig({
    String? url,
    String? anonKey,
    String? env,
  }) {
    final effectiveUrl = (url ?? supabaseUrl).trim();
    final effectiveKey = (anonKey ?? supabaseAnonKey).trim();

    if (effectiveUrl.isEmpty) {
      throw const AppConfigurationException(
          'Missing SUPABASE_URL configuration.');
    }
    if (!effectiveUrl.startsWith('http://') &&
        !effectiveUrl.startsWith('https://')) {
      throw const AppConfigurationException(
          'Invalid SUPABASE_URL protocol. Must start with http:// or https://');
    }
    if (effectiveKey.isEmpty) {
      throw const AppConfigurationException(
          'Missing SUPABASE_ANON_KEY configuration.');
    }
  }
}
