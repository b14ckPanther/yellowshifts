import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';
import '../permissions/platform_admin_provider.dart';
import '../permissions/station_access_context.dart';
import '../../features/stations/presentation/active_station_provider.dart';
import '../../shared/models/user_profile.dart';

/// Flag indicating the user has explicitly requested sign out in the current session.
final isExplicitlySignedOutProvider = StateProvider<bool>((ref) => false);

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

final currentAuthUserProvider = Provider<User?>((ref) {
  final explicitlySignedOut = ref.watch(isExplicitlySignedOutProvider);
  if (explicitlySignedOut) return null;

  final authState = ref.watch(authStateStreamProvider);
  if (authState.hasError) return null;
  if (authState.hasValue) {
    final state = authState.value!;
    if (state.event == AuthChangeEvent.signedOut || state.session == null) {
      return null;
    }
    return state.session?.user;
  }
  return ref.watch(authRepositoryProvider).currentUser;
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getCurrentProfile();
});

/// Centralized robust sign-out handler that guarantees instantaneous auth state
/// clearance, resets station context, triggers remote/local signout, and routes to /login.
Future<void> performSignOut(WidgetRef ref, [BuildContext? context]) async {
  // 1. Immediately drop auth credentials in memory synchronously
  ref.read(isExplicitlySignedOutProvider.notifier).state = true;
  ref.read(platformOperatingStationIdProvider.notifier).state = null;
  ref.read(activeStationIdProvider.notifier).selectStation('');

  // 2. Invalidate all user/membership caches
  ref.invalidate(userMembershipsStreamProvider);
  ref.invalidate(currentProfileProvider);
  ref.invalidate(isPlatformAdminProvider);
  ref.invalidate(stationAccessContextProvider);

  // 3. Immediately route to /login if context is mounted
  if (context != null && context.mounted) {
    try {
      context.go('/login');
    } catch (_) {}
  }

  // 4. Perform network & local storage signOut via repository
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (_) {}
}
