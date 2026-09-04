import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Parsed NFC Station Tag Payload from physical tag
@immutable
class NfcStationTagPayload {
  final int version;
  final String stationCode;
  final String tagIdentifier;
  final String rawSecret;

  const NfcStationTagPayload({
    required this.version,
    required this.stationCode,
    required this.tagIdentifier,
    required this.rawSecret,
  });

  factory NfcStationTagPayload.fromJson(Map<String, dynamic> json) {
    return NfcStationTagPayload(
      version: (json['v'] as num?)?.toInt() ?? 1,
      stationCode: (json['station_code'] as String?)?.trim() ?? '',
      tagIdentifier: (json['tag_id'] as String?)?.trim() ?? '',
      rawSecret: (json['secret'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'station_code': stationCode,
        'tag_id': tagIdentifier,
        'secret': rawSecret,
      };

  String serialize() => jsonEncode(toJson());

  static NfcStationTagPayload? parseRawString(String raw) {
    try {
      final clean = raw.trim();
      if (!clean.startsWith('{') || !clean.endsWith('}')) {
        return null;
      }
      final map = jsonDecode(clean) as Map<String, dynamic>;
      final payload = NfcStationTagPayload.fromJson(map);
      if (payload.tagIdentifier.isEmpty || payload.rawSecret.isEmpty) {
        return null;
      }
      return payload;
    } catch (_) {
      return null;
    }
  }
}

/// Abstract contract for NFC operations allowing clean dependency injection & unit testing
abstract class NfcService {
  Future<bool> isAvailable();

  Future<void> startStationTagScan({
    required void Function(NfcStationTagPayload payload) onTagScanned,
    required void Function(String error) onError,
    String? alertMessage,
  });

  Future<void> writeStationTag({
    required NfcStationTagPayload payload,
    required void Function() onSuccess,
    required void Function(String error) onError,
    String? alertMessage,
  });

  Future<void> stopSession({String? alertMessage, String? errorMessage});
}

/// Default production NFC implementation backed by NfcManager
class DeviceNfcService implements NfcService {
  bool _isSessionActive = false;

  @override
  Future<bool> isAvailable() async {
    try {
      if (kIsWeb) return false;
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('[NfcService] isAvailable check failed: $e');
      return false;
    }
  }

  @override
  Future<void> startStationTagScan({
    required void Function(NfcStationTagPayload payload) onTagScanned,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    final available = await isAvailable();
    if (!available) {
      onError('NFC is unavailable or disabled on this device.');
      return;
    }

    if (_isSessionActive) {
      await stopSession();
    }

    _isSessionActive = true;

    try {
      await NfcManager.instance.startSession(
        alertMessage:
            alertMessage ?? 'Hold your phone near the station NFC tag.',
        onError: (error) async {
          _isSessionActive = false;
          onError(error.message);
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final payload = _extractNfcPayload(tag);
            if (payload != null) {
              await stopSession();
              onTagScanned(payload);
            } else {
              onError('Unrecognized or invalid YellowShifts NFC station tag.');
            }
          } catch (e) {
            onError('Failed to read NFC tag: $e');
          }
        },
      );
    } catch (e) {
      _isSessionActive = false;
      onError('Failed to start NFC scan: $e');
    }
  }

  @override
  Future<void> writeStationTag({
    required NfcStationTagPayload payload,
    required void Function() onSuccess,
    required void Function(String error) onError,
    String? alertMessage,
  }) async {
    final available = await isAvailable();
    if (!available) {
      onError('NFC is unavailable or disabled on this device.');
      return;
    }

    if (_isSessionActive) {
      await stopSession();
    }

    _isSessionActive = true;

    try {
      await NfcManager.instance.startSession(
        alertMessage: alertMessage ??
            'Hold phone near blank NFC tag to write station data.',
        onError: (error) async {
          _isSessionActive = false;
          onError(error.message);
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await stopSession(
                  errorMessage: 'Tag does not support NDEF formatting.');
              onError(
                  'This NFC tag does not support standard NDEF formatting.');
              return;
            }

            if (!ndef.isWritable) {
              await stopSession(errorMessage: 'Tag is read-only or locked.');
              onError('This NFC tag is read-only or permanently locked.');
              return;
            }

            final record = NdefRecord.createText(payload.serialize());
            final message = NdefMessage([record]);

            await ndef.write(message);
            await stopSession(
                alertMessage: 'NFC Tag provisioned successfully!');
            onSuccess();
          } catch (e) {
            await stopSession(errorMessage: 'Write failed.');
            onError('Failed to write NFC tag: $e');
          }
        },
      );
    } catch (e) {
      _isSessionActive = false;
      onError('Failed to start NFC write session: $e');
    }
  }

  @override
  Future<void> stopSession({String? alertMessage, String? errorMessage}) async {
    if (!_isSessionActive) return;
    _isSessionActive = false;
    try {
      await NfcManager.instance.stopSession(
        alertMessage: alertMessage,
        errorMessage: errorMessage,
      );
    } catch (e) {
      debugPrint('[NfcService] stopSession error: $e');
    }
  }

  NfcStationTagPayload? _extractNfcPayload(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef == null) return null;

    final message = ndef.cachedMessage;
    if (message == null || message.records.isEmpty) return null;

    for (final record in message.records) {
      final text = _decodeRecordPayload(record);
      if (text != null) {
        final parsed = NfcStationTagPayload.parseRawString(text);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  String? _decodeRecordPayload(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return null;

      // Check NDEF Text Record format (TNF = Well Known, Type = 'T')
      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          record.type.length == 1 &&
          record.type.first == 0x54) {
        final statusByte = payload[0];
        final languageCodeLength = statusByte & 0x3F;
        final isUtf16 = (statusByte & 0x80) != 0;

        final textBytes = payload.sublist(1 + languageCodeLength);
        if (isUtf16) {
          return String.fromCharCodes(Uint16List.view(textBytes.buffer));
        } else {
          return utf8.decode(textBytes);
        }
      }

      // Fallback: direct UTF-8 decode
      return utf8.decode(payload);
    } catch (_) {
      return null;
    }
  }
}

/// Central Riverpod provider for NfcService
final nfcServiceProvider = Provider<NfcService>((ref) {
  return DeviceNfcService();
});
