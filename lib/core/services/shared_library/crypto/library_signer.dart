import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

/// A member's Ed25519 key pair, base64 (issue #2567). The private half is
/// the 32-byte seed the pair is rebuilt from.
class LibrarySigningKey {
  const LibrarySigningKey({required this.publicKey, required this.privateKey});

  final String publicKey;
  final String privateKey;
}

/// Signing and checking for shared site libraries (issue #2567).
abstract final class LibrarySigner {
  static final _ed = Ed25519();

  static Future<LibrarySigningKey> generate() async =>
      _from(await _ed.newKeyPair());

  static Future<LibrarySigningKey> fromSeed(List<int> seed) async =>
      _from(await _ed.newKeyPairFromSeed(seed));

  static Future<LibrarySigningKey> _from(SimpleKeyPair pair) async =>
      LibrarySigningKey(
        publicKey: base64Encode((await pair.extractPublicKey()).bytes),
        privateKey: base64Encode(await pair.extractPrivateKeyBytes()),
      );

  static Future<String> sign(LibrarySigningKey key, List<int> message) async {
    final pair = await _ed.newKeyPairFromSeed(base64Decode(key.privateKey));
    final signature = await _ed.sign(message, keyPair: pair);
    return base64Encode(signature.bytes);
  }

  /// False for a missing, malformed or wrong signature or key: an edit that
  /// cannot be checked counts exactly like a forged one.
  static Future<bool> verify({
    required String publicKey,
    required List<int> message,
    required String? signature,
  }) async {
    if (signature == null) return false;
    try {
      final pub = SimplePublicKey(
        base64Decode(publicKey),
        type: KeyPairType.ed25519,
      );
      return await _ed.verify(
        message,
        signature: Signature(base64Decode(signature), publicKey: pub),
      );
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }
  }

  /// The first 16 hex digits of the public key's SHA-256, upper case, in
  /// groups of four: short enough to read out and compare in person.
  static String fingerprint(String publicKey) {
    final hex = hash.sha256
        .convert(base64Decode(publicKey))
        .toString()
        .substring(0, 16)
        .toUpperCase();
    return [for (var i = 0; i < 16; i += 4) hex.substring(i, i + 4)].join(' ');
  }
}
