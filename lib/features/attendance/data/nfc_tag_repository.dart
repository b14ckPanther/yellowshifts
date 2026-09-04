import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/station_nfc_tag.dart';

class NfcTagRepository {
  final SupabaseClient _supabase;

  NfcTagRepository(this._supabase);

  Future<Map<String, dynamic>> provisionStationNfcTag({
    required String stationId,
    required String name,
  }) async {
    final res = await _supabase.rpc('provision_station_nfc_tag', params: {
      'p_station_id': stationId,
      'p_name': name.trim(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<StationNfcTag>> listStationNfcTags(String stationId) async {
    final res = await _supabase.rpc('list_station_nfc_tags', params: {
      'p_station_id': stationId,
    });
    final list = res as List<dynamic>? ?? [];
    return list
        .map((e) => StationNfcTag.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> revokeStationNfcTag(String tagId) async {
    await _supabase.rpc('revoke_station_nfc_tag', params: {
      'p_tag_id': tagId,
    });
  }

  Future<void> reactivateStationNfcTag(String tagId) async {
    await _supabase.rpc('reactivate_station_nfc_tag', params: {
      'p_tag_id': tagId,
    });
  }

  Future<Map<String, dynamic>> replaceStationNfcTag({
    required String oldTagId,
    required String newName,
  }) async {
    final res = await _supabase.rpc('replace_station_nfc_tag', params: {
      'p_old_tag_id': oldTagId,
      'p_new_name': newName.trim(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> regenerateStationNfcTag(String tagId) async {
    final res = await _supabase.rpc('regenerate_station_nfc_tag', params: {
      'p_tag_id': tagId,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}
