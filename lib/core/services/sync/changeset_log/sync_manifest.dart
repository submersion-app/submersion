import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// The per-device manifest: the small, rewritten-each-publish "commit point"
/// that names the current base and changeset range. The only mutable file in
/// a device's namespace.
class SyncManifest {
  const SyncManifest({
    required this.deviceId,
    required this.provider,
    required this.headSeq,
    required this.updatedAt,
    this.baseSeq,
    this.basePartCount,
    this.baseBytes,
    this.baseChecksum,
    this.basePartChecksums = const [],
    this.publishedHlcHigh,
    this.epochId,
    this.uploadNonce,
    this.appliedPeerHlc = const {},
    this.formatVersion = 1,
    this.schemaVersion,
    this.writerSchemaVersion,
    this.deviceName,
  });

  final int formatVersion;

  /// The oldest database schema that can apply this device's payloads
  /// without loss (the compatibility floor,
  /// AppDatabase.minimumCompatibleSchemaVersion). Readers hold a peer when
  /// this exceeds their own schema. Manifests written before 2026-08 carried
  /// the writer's actual schema version here instead, which is strictly
  /// higher, so old manifests are held MORE eagerly, never less safely. The
  /// writer's true version now travels in [writerSchemaVersion]. Null on
  /// manifests written before the field existed.
  final int? schemaVersion;

  /// The publishing device's actual database schema version, for
  /// diagnostics and support tooling. Never used for gating; the gate
  /// compares [schemaVersion]. Null on manifests written before the field
  /// existed.
  final int? writerSchemaVersion;

  /// Display name of the publishing device, used to name peers in the "still
  /// needs to adopt" banner. Null on manifests written before this field
  /// existed, and on devices that nothing identifies by name (see
  /// DeviceDisplayNameService), so readers must fall back to the device id.
  final String? deviceName;
  final String deviceId;
  final String provider;
  final int? baseSeq;
  final int? basePartCount;
  final int? baseBytes;
  final String? baseChecksum;
  final List<String> basePartChecksums;
  final int headSeq;
  final String? publishedHlcHigh;
  final String? epochId;
  final String? uploadNonce;
  final int updatedAt;

  /// Highest HLC this device has APPLIED from each peer's log
  /// (peerDeviceId -> hlc). Peers read it to garbage-collect tombstones every
  /// live device has provably seen. A missing entry acknowledges nothing.
  final Map<String, String> appliedPeerHlc;

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'writerSchemaVersion': writerSchemaVersion,
    'deviceName': deviceName,
    'deviceId': deviceId,
    'provider': provider,
    'baseSeq': baseSeq,
    'basePartCount': basePartCount,
    'baseBytes': baseBytes,
    'baseChecksum': baseChecksum,
    'basePartChecksums': basePartChecksums,
    'headSeq': headSeq,
    'publishedHlcHigh': publishedHlcHigh,
    'epochId': epochId,
    'uploadNonce': uploadNonce,
    'appliedPeerHlc': appliedPeerHlc,
    'updatedAt': updatedAt,
  };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
    formatVersion: (json['formatVersion'] as int?) ?? 1,
    schemaVersion: json['schemaVersion'] as int?,
    writerSchemaVersion: json['writerSchemaVersion'] as int?,
    deviceName: json['deviceName'] as String?,
    deviceId: json['deviceId'] as String,
    provider: json['provider'] as String,
    baseSeq: json['baseSeq'] as int?,
    basePartCount: json['basePartCount'] as int?,
    baseBytes: json['baseBytes'] as int?,
    baseChecksum: json['baseChecksum'] as String?,
    basePartChecksums: ((json['basePartChecksums'] as List?) ?? const [])
        .cast<String>(),
    headSeq: (json['headSeq'] as int?) ?? 0,
    publishedHlcHigh: json['publishedHlcHigh'] as String?,
    epochId: json['epochId'] as String?,
    uploadNonce: json['uploadNonce'] as String?,
    appliedPeerHlc: Map<String, String>.from(
      (json['appliedPeerHlc'] as Map?) ?? const {},
    ),
    updatedAt: (json['updatedAt'] as int?) ?? 0,
  );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory SyncManifest.fromBytes(Uint8List bytes) {
    // Defense in depth for encrypted libraries: never let an SBE1 envelope
    // masquerade as a corrupt manifest (spec section 4.3).
    if (SyncEnvelope.hasMagic(bytes)) {
      throw SyncEncryptionRequired(
        libraryKeyId: SyncEnvelope.libraryKeyIdOf(bytes),
        message: 'Sync manifest is encrypted',
      );
    }
    return SyncManifest.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}
