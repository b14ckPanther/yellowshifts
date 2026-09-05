import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';
import '../../shared/models/user_profile.dart';

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

final currentAuthUserProvider = Provider<User?>((ref) {
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
