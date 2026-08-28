import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/lifecycle/app_startup_state.dart';
import 'package:yellowshifts/core/lifecycle/startup_screen.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

void main() {
  group('AppStartupState V2 Compatibility & Phase Tests', () {
    test('Correctly identifies clientOutdated phase as error state', () {
      const state = AppStartupState(
        phase: StartupPhase.clientOutdated,
        minClientVersion: '1.2.0',
        errorMessage: 'Client version is outdated',
      );

      expect(state.isReady, isFalse);
      expect(state.hasError, isTrue);
      expect(state.isLoading, isFalse);
    });

    test('Correctly identifies schemaIncompatible phase as error state', () {
      const state = AppStartupState(
        phase: StartupPhase.schemaIncompatible,
        errorMessage: 'Schema mismatch',
      );

      expect(state.isReady, isFalse);
      expect(state.hasError, isTrue);
      expect(state.isLoading, isFalse);
    });
  });

  group('StartupScreen V2 Widget Tests for Outdated Client', () {
    Widget buildTestHarness(AppStartupState state) {
      return ProviderScope(
        overrides: [
          appStartupStateProvider.overrideWithValue(state),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupScreen(),
        ),
      );
    }

    testWidgets('Renders update required message when client is outdated',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(const AppStartupState(
          phase: StartupPhase.clientOutdated,
          minClientVersion: '1.2.0',
          errorMessage: 'Application update is required to continue.',
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('update is required'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
