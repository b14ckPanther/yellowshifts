import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/kiosk_device.dart';
import '../domain/models/qr_challenge.dart';

class KioskRepository {
  final SupabaseClient _supabase;

  KioskRepository(this._supabase);

  Future<List<KioskDevice>> getKioskDevices(String stationId) async {
    final res = await _supabase
        .from('kiosk_devices')
        .select()
        .eq('station_id', stationId)
        .order('created_at', ascending: true);

    return (res as List<dynamic>)
        .map((e) => KioskDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> provisionKioskDevice({
    required String stationId,
    required String name,
    required String deviceIdentifier,
  }) async {
    final res = await _supabase.rpc('provision_kiosk_device', params: {
      'p_station_id': stationId,
      'p_name': name,
      'p_device_identifier': deviceIdentifier,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> rotateKioskCredentials(
      String kioskDeviceId) async {
    final res = await _supabase.rpc('rotate_kiosk_credentials', params: {
      'p_kiosk_device_id': kioskDeviceId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deactivateKioskDevice(String kioskDeviceId) async {
    await _supabase.rpc('deactivate_kiosk_device', params: {
      'p_kiosk_device_id': kioskDeviceId,
    });
  }

  Future<void> reactivateKioskDevice(String kioskDeviceId) async {
    await _supabase.rpc('reactivate_kiosk_device', params: {
      'p_kiosk_device_id': kioskDeviceId,
    });
  }

  Future<QrChallenge> authenticateAndMintQr({
    String? stationId,
    required String deviceIdentifier,
    required String deviceSecret,
  }) async {
    final res = await _supabase.rpc('kiosk_authenticate_and_mint_qr', params: {
      'p_station_id':
          (stationId != null && stationId.isNotEmpty) ? stationId : null,
      'p_device_identifier': deviceIdentifier,
      'p_device_secret': deviceSecret,
    });
    return QrChallenge.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
