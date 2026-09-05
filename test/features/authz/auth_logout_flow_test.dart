import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yellowshifts/app/routing/app_router.dart';
import 'package:yellowshifts/core/auth/auth_repository.dart';
import 'package:yellowshifts/core/auth/auth_state_provider.dart';
import 'package:yellowshifts/core/permissions/station_access_context.dart';
import 'package:yellowshifts/shared/models/user_profile.dart';

class MockTestAuthRepository implements AuthRepository {
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  User? _currentUser;

  MockTestAuthRepository({User? initialUser}) : _currentUser = initialUser;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  void emitState(AuthState state) {
    _currentUser = state.session?.user;
    _controller.add(state);
  }

  @override
  Future<void> signInWithPassword(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<UserProfile?> getCurrentProfile() async => null;

  @override
  Future<void> updateProfile(UserProfile profile) async {}

  void dispose() {
    _controller.close();
  }
}

GoRouterState _makeState(String path) {
  final uri = Uri.parse(path);
  final router = GoRouter(routes: []);
  return GoRouterState(
    router.configuration,
    uri: uri,
    matchedLocation: uri.path,
    fullPath: uri.path,
    pathParameters: const {},
    pageKey: const ValueKey('test'),
  );
}

void main() {
  group('Auth Logout and Router Transition Tests', () {
    late MockTestAuthRepository mockRepo;
    final testUser = User(
      id: 'test-user-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    setUp(() {
      mockRepo = MockTestAuthRepository(initialUser: testUser);
    });

    tearDown(() {
      mockRepo.dispose();
    });

    test('currentAuthUserProvider returns null immediately on signedOut event',
        () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial state with user
      mockRepo.emitState(AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: testUser,
        ),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(currentAuthUserProvider), isNotNull);
      expect(container.read(currentAuthUserProvider)!.id, 'test-user-123');

      // Now trigger signOut
      await mockRepo.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Must be null immediately without relying on manual refresh
      expect(container.read(currentAuthUserProvider), isNull);
    });

    test('RouterNotifier redirect forces /login when user is unauthenticated',
        () {
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          stationAccessContextProvider
              .overrideWithValue(StationAccessContext.unauthenticated()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routerNotifierProvider);
      final fakeContext = _FakeBuildContext();

      // Attempting to visit /dashboard while unauthenticated
      final redirectResult = notifier.redirect(
        fakeContext,
        _makeState('/dashboard'),
      );

      expect(redirectResult, '/login');
    });

    test('RouterNotifier allows /login when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          currentAuthUserProvider.overrideWithValue(null),
          stationAccessContextProvider
              .overrideWithValue(StationAccessContext.unauthenticated()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routerNotifierProvider);
      final fakeContext = _FakeBuildContext();

      // Visiting /login while unauthenticated
      final redirectResult = notifier.redirect(
        fakeContext,
        _makeState('/login'),
      );

      // Must return null to stay on /login
      expect(redirectResult, isNull);
    });

    test(
        'setting isExplicitlySignedOutProvider immediately forces currentAuthUserProvider to null',
        () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentAuthUserProvider), isNotNull);

      // Force sign out synchronously
      container.read(isExplicitlySignedOutProvider.notifier).state = true;

      // Immediately null without waiting for any async ticks or stream events
      expect(container.read(currentAuthUserProvider), isNull);
    });
  });
}

class _FakeBuildContext extends Fake implements BuildContext {}
