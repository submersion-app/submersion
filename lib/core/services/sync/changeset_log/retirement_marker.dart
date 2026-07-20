import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// Durable record that a device's changeset log was retired (deleted from the
/// cloud after 12+ months of inactivity). Written BEFORE the log is deleted so
/// the returning device always detects its retirement and rejoins through the
/// fence rather than resurrecting stale data. Persists until the device
/// rejoins (it deletes its own marker at the end of the fence flow).
class RetirementMarker {
  const RetirementMarker({
    required this.deviceId,
    required this.retiredAt,
    this.formatVersion = 1,
  });

  final int formatVersion;
  final String deviceId;
  final int retiredAt;

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'deviceId': deviceId,
    'retiredAt': retiredAt,
  };

  factory RetirementMarker.fromJson(Map<String, dynamic> json) =>
      RetirementMarker(
        formatVersion: (json['formatVersion'] as int?) ?? 1,
        deviceId: json['deviceId'] as String,
        retiredAt: (json['retiredAt'] as int?) ?? 0,
      );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory RetirementMarker.fromBytes(Uint8List bytes) {
    // Defense in depth for encrypted libraries: never let an SBE1 envelope
    // masquerade as a corrupt marker (mirrors SyncManifest.fromBytes).
    if (SyncEnvelope.hasMagic(bytes)) {
      throw SyncEncryptionRequired(
        libraryKeyId: SyncEnvelope.libraryKeyIdOf(bytes),
        message: 'Retirement marker is encrypted',
      );
    }
    return RetirementMarker.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}
