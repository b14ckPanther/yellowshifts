import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider delivering the configured SupabaseClient singleton.
/// Falls back safely to a sandbox client in test environments where
/// [Supabase.initialize] has not been called.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return SupabaseClient(
      'https://mock-test-environment.yellowshifts.local',
      'mock-test-anon-key',
    );
  }
});
