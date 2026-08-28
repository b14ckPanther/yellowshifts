import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/app_failure.dart';
import '../supabase/supabase_client_provider.dart';
import '../../shared/models/user_profile.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Future<UserProfile?> getCurrentProfile();
  Future<void> signInWithPassword(
      {required String email, required String password});
  Future<void> signOut();
  Future<void> updateProfile(UserProfile profile);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<void> signInWithPassword(
      {required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.statusCode, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    try {
      await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});
