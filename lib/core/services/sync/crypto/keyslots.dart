import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'package:submersion/core/services/sync/crypto/recovery_code.dart';

/// Argon2id parameters, stored per slot so they can be raised later by
/// rewrapping. Package unit note: `m` is in 1-KiB blocks (65536 = 64 MiB).
class KdfParams {
  final String alg;
  final int m;
  final int t;
  final int p;

  const KdfParams({
    this.alg = 'argon2id',
    this.m = 65536,
    this.t = 3,
    this.p = 1,
  });

  Map<String, dynamic> toJson() => {'alg': alg, 'm': m, 't': t, 'p': p};

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    alg: json['alg'] as String,
    m: json['m'] as int,
    t: json['t'] as int,
    p: json['p'] as int,
  );
}

/// One wrapped copy of the master library key.
class Keyslot {
  final String type; // 'passphrase' | 'recovery'
  final Uint8List salt;
  final KdfParams kdf;
  final Uint8List nonce;
  final Uint8List wrapped; // AES-256-GCM(MLK) ciphertext||tag

  const Keyslot({
    required this.type,
    required this.salt,
    required this.kdf,
    required this.nonce,
    required this.wrapped,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'salt': base64Encode(salt),
    'kdf': kdf.toJson(),
    'nonce': base64Encode(nonce),
    'wrapped': base64Encode(wrapped),
  };

  factory Keyslot.fromJson(Map<String, dynamic> json) => Keyslot(
    type: json['type'] as String,
    salt: base64Decode(json['salt'] as String),
    kdf: KdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
    nonce: base64Decode(json['nonce'] as String),
    wrapped: base64Decode(json['wrapped'] as String),
  );
}

/// The one plaintext cloud file: wrapped keys plus their KDF parameters.
class KeyslotFile {
  /// Must not contain the 'submersion_sync' discovery stem (same rule as
  /// the epoch marker, see library_epoch.dart).
  static const String cloudFileName = 'submersion_keyslots.json';

  final int version;
  final String libraryKeyId;
  final List<Keyslot> slots;

  const KeyslotFile({
    required this.version,
    required this.libraryKeyId,
    required this.slots,
  });

  Uint8List toJsonBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': version,
        'libraryKeyId': libraryKeyId,
        'slots': [for (final s in slots) s.toJson()],
      }),
    ),
  );

  factory KeyslotFile.fromJsonBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return KeyslotFile(
      version: json['version'] as int,
      libraryKeyId: json['libraryKeyId'] as String,
      slots: [
        for (final s in json['slots'] as List)
          Keyslot.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  /// Replace the slot sharing [slot]'s type, or append when absent.
  KeyslotFile withReplacedSlot(Keyslot slot) => KeyslotFile(
    version: version,
    libraryKeyId: libraryKeyId,
    slots: [
      for (final s in slots)
        if (s.type != slot.type) s,
      slot,
    ],
  );
}

abstract final class Keyslots {
  static final AesGcm _aesGcm = AesGcm.with256bits();

  static Future<SecretKey> deriveKek({
    required String secret,
    required Uint8List salt,
    required KdfParams kdf,
  }) {
    final argon2id = Argon2id(
      parallelism: kdf.p,
      memory: kdf.m,
      iterations: kdf.t,
      hashLength: 32,
    );
    return argon2id.deriveKeyFromPassword(password: secret, nonce: salt);
  }

  static Future<Keyslot> createSlot({
    required String type,
    required String secret,
    required SecretKey mlk,
    KdfParams kdf = const KdfParams(),
    Uint8List? saltForTest,
    List<int>? nonceForTest,
  }) async {
    final salt = saltForTest ?? _randomBytes(16);
    final kek = await deriveKek(secret: secret, salt: salt, kdf: kdf);
    final box = await _aesGcm.encrypt(
      await mlk.extractBytes(),
      secretKey: kek,
      nonce: nonceForTest ?? _aesGcm.newNonce(),
    );
    return Keyslot(
      type: type,
      salt: salt,
      kdf: kdf,
      nonce: Uint8List.fromList(box.nonce),
      wrapped: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  static Future<SecretKey?> tryUnwrap({
    required KeyslotFile file,
    required String secret,
  }) async {
    for (final slot in file.slots) {
      final candidate = slot.type == 'recovery'
          ? RecoveryCode.normalize(secret)
          : secret;
      final kek = await deriveKek(
        secret: candidate,
        salt: slot.salt,
        kdf: slot.kdf,
      );
      final box = SecretBox(
        Uint8List.sublistView(slot.wrapped, 0, slot.wrapped.length - 16),
        nonce: slot.nonce,
        mac: Mac(Uint8List.sublistView(slot.wrapped, slot.wrapped.length - 16)),
      );
      try {
        final mlkBytes = await _aesGcm.decrypt(box, secretKey: kek);
        return SecretKey(mlkBytes);
      } on SecretBoxAuthenticationError {
        continue;
      }
    }
    return null;
  }

  static Future<SecretKey> deriveDataKey(SecretKey mlk) async {
    // Pinned to the pure-Dart HKDF: the salt is empty (RFC 5869 default),
    // HKDF keys its extract HMAC with the salt, and the cryptography_flutter
    // implementation that auto-registers as Cryptography.instance on Android
    // rejects empty HMAC keys (SecretKeySpec "Empty key", #737). Output is
    // byte-identical on every platform either way.
    const hkdf = DartHkdf(hmac: DartHmac(DartSha256()), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: mlk,
      nonce: const <int>[],
      info: utf8.encode('sbe:v1:data'),
    );
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
