import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../data/nfc_tag_repository.dart';
import '../../domain/models/station_nfc_tag.dart';

final nfcTagRepositoryProvider = Provider<NfcTagRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return NfcTagRepository(supabase);
});

final stationNfcTagsProvider =
    FutureProvider.family<List<StationNfcTag>, String>((ref, stationId) async {
  final repo = ref.watch(nfcTagRepositoryProvider);
  return repo.listStationNfcTags(stationId);
});
