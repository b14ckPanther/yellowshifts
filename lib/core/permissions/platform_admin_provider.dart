import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_state_provider.dart';
import '../supabase/supabase_client_provider.dart';

/// Server-authoritative platform-admin flag. Fail-closed while loading or on error.
final isPlatformAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return false;
  try {
    final client = ref.watch(supabaseClientProvider);
    final result = await client.rpc('is_platform_admin');
    return result == true;
  } catch (_) {
    return false;
  }
});

final isPlatformAdminValueProvider = Provider<bool>((ref) {
  return ref.watch(isPlatformAdminProvider).maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );
});

/// Explicit station context when a Platform Admin operates a station
/// without holding a station_memberships row.
final platformOperatingStationIdProvider =
    StateProvider<String?>((ref) => null);
