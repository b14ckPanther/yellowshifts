import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/app/config/app_config.dart';

void main() {
  group('AppConfig & Environment Contract Tests', () {
    test('AppEnvironment parsing works correctly', () {
      expect(
          AppEnvironment.fromString('production'), AppEnvironment.production);
      expect(AppEnvironment.fromString('prod'), AppEnvironment.production);
      expect(AppEnvironment.fromString('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromString('stage'), AppEnvironment.staging);
      expect(
          AppEnvironment.fromString('development'), AppEnvironment.development);
      expect(AppEnvironment.fromString('dev'), AppEnvironment.development);
      expect(AppEnvironment.fromString('unknown'), AppEnvironment.development);
    });

    test('Release identity metadata is correctly formatted', () {
      expect(AppConfig.appVersion, '1.0.5');
      expect(AppConfig.buildNumber, 11);
      expect(AppConfig.releaseIdentifier, '1.0.5+11');
      expect(AppConfig.minimumBackendSchemaVersion, '20260825000019');
    });

    test('validateConfig succeeds for valid HTTPS URL and non-empty key', () {
      expect(
        () => AppConfig.validateConfig(
          url: 'https://example.supabase.co',
          anonKey: 'valid-anon-key-sample',
        ),
        returnsNormally,
      );
    });

    test('validateConfig throws AppConfigurationException for empty URL', () {
      expect(
        () => AppConfig.validateConfig(
          url: '',
          anonKey: 'valid-anon-key',
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test(
        'validateConfig throws AppConfigurationException for non-http(s) protocol',
        () {
      expect(
        () => AppConfig.validateConfig(
          url: 'ftp://invalid-url.local',
          anonKey: 'valid-anon-key',
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('validateConfig throws AppConfigurationException for empty anonKey',
        () {
      expect(
        () => AppConfig.validateConfig(
          url: 'https://example.supabase.co',
          anonKey: '   ',
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });
  });
}
