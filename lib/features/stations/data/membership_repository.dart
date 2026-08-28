import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/station_membership.dart';

abstract class MembershipRepository {
  Future<List<StationMembership>> getMembershipsForUser(String userId);
  Stream<List<StationMembership>> streamMembershipsForUser(String userId);
}

class SupabaseMembershipRepository implements MembershipRepository {
  final SupabaseClient _client;

  SupabaseMembershipRepository(this._client);

  @override
  Future<List<StationMembership>> getMembershipsForUser(String userId) async {
    try {
      final response = await _client
          .from('station_memberships')
          .select('*, stations(*)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE');

      return (response as List<dynamic>)
          .map((json) =>
              StationMembership.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message, code: e.code, originalError: e);
    } catch (e) {
      throw UnknownFailure(e.toString(), originalError: e);
    }
  }

  @override
  Stream<List<StationMembership>> streamMembershipsForUser(
      String userId) async* {
    List<StationMembership> lastKnown = const [];
    try {
      lastKnown = await getMembershipsForUser(userId);
      yield lastKnown;
    } catch (_) {}

    try {
      final stream = _client
          .from('station_memberships')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .asyncMap((_) async {
            try {
              lastKnown = await getMembershipsForUser(userId);
              return lastKnown;
            } catch (_) {
              return lastKnown;
            }
          })
          .handleError((_) {});

      yield* stream;
    } catch (_) {}
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseMembershipRepository(client);
});
