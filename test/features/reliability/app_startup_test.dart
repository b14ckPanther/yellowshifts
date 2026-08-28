import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/lifecycle/app_startup_state.dart';
import 'package:yellowshifts/core/lifecycle/startup_screen.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

void main() {
  group('AppStartupState Unit Tests', () {
    test('isReady is true only for authenticatedStationReady', () {
      const readyState =
          AppStartupState(phase: StartupPhase.authenticatedStationReady);
      expect(readyState.isReady, isTrue);
      expect(readyState.isLoading, isFalse);
      expect(readyState.hasError, isFalse);

      const bootingState = AppStartupState(phase: StartupPhase.booting);
      expect(bootingState.isReady, isFalse);
      expect(bootingState.isLoading, isTrue);

      const errState = AppStartupState(
        phase: StartupPhase.configError,
        errorMessage: 'Invalid config',
      );
      expect(errState.isReady, isFalse);
      expect(errState.hasError, isTrue);
    });

    test('isLoading reports true for booting and loading phases', () {
      expect(
          const AppStartupState(phase: StartupPhase.booting).isLoading, isTrue);
      expect(const AppStartupState(phase: StartupPhase.authLoading).isLoading,
          isTrue);
      expect(
        const AppStartupState(phase: StartupPhase.authenticatedLoadingStations)
            .isLoading,
        isTrue,
      );
      expect(
        const AppStartupState(phase: StartupPhase.unauthenticated).isLoading,
        isFalse,
      );
    });
  });

  group('StartupScreen Widget Tests', () {
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

    testWidgets('Displays loading indicator and startup message when booting',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(const AppStartupState(phase: StartupPhase.booting)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Displays config error screen on configuration failure',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(const AppStartupState(
          phase: StartupPhase.configError,
          errorMessage: 'Missing SUPABASE_URL parameter',
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Missing SUPABASE_URL'), findsOneWidget);
    });

    testWidgets('Displays access revoked error when membership deactivated',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(const AppStartupState(
          phase: StartupPhase.authenticatedStationAccessRevoked,
        )),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
