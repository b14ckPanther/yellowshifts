import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yellowshifts/core/design_system/widgets/app_connectivity_banner.dart';
import 'package:yellowshifts/core/network/connectivity_service.dart';
import 'package:yellowshifts/l10n/app_localizations.dart';

class MockConnectivityNotifier extends ConnectivityNotifier {
  final NetworkConnectionState initialState;
  MockConnectivityNotifier(this.initialState);

  @override
  NetworkConnectionState get state => initialState;
}

void main() {
  group('NetworkConnectionState Unit Tests', () {
    test('isOnline reports true for online state', () {
      const state = NetworkConnectionState.online;
      expect(state.isOnline, isTrue);
      expect(state.isOffline, isFalse);
      expect(state.isReconnecting, isFalse);
    });

    test('isOffline reports true for offline state', () {
      const state = NetworkConnectionState.offline;
      expect(state.isOnline, isFalse);
      expect(state.isOffline, isTrue);
    });

    test('isReconnecting reports true for reconnecting state', () {
      const state = NetworkConnectionState.reconnecting;
      expect(state.isOnline, isFalse);
      expect(state.isReconnecting, isTrue);
    });
  });

  group('AppConnectivityBanner Widget Tests', () {
    Widget buildTestHarness(NetworkConnectionState state) {
      return ProviderScope(
        overrides: [
          connectivityProvider
              .overrideWith((ref) => MockConnectivityNotifier(state)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                AppConnectivityBanner(),
                Expanded(child: Text('Main Content')),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('Renders empty SizedBox when online', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(NetworkConnectionState.online),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.wifiOff), findsNothing);
      expect(find.text('Main Content'), findsOneWidget);
    });

    testWidgets('Renders offline banner with wifiOff icon when offline',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(NetworkConnectionState.offline),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.wifiOff), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets(
        'Renders reconnecting banner with refresh icon when reconnecting',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(NetworkConnectionState.reconnecting),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
      expect(find.textContaining('Reconnecting'), findsOneWidget);
    });
  });
}
