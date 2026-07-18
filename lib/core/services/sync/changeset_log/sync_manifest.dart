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
  });

  final int formatVersion;
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
