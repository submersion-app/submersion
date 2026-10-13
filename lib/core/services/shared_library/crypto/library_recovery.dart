import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';

/// A shared site library's recovery code and the owner-level signing key it
/// stands for (issue #2567). The key lives on no device: the code becomes
/// it only when typed in.
class LibraryRecoveryKey {
  const LibraryRecoveryKey({
    required this.code,
    required this.key,
    required this.salt,
    required this.kdf,
  });

  final String code;
  final LibrarySigningKey key;
  final String salt;
  final KdfParams kdf;

  /// The `recovery` entry of `roles.json`: everything but the code.
  Map<String, dynamic> toRolesJson() => {
    'publicKey': key.publicKey,
    'salt': salt,
    'kdf': kdf.toJson(),
  };
}

abstract final class LibraryRecovery {
  static Future<LibraryRecoveryKey> create({
    KdfParams kdf = const KdfParams(),
  }) async {
    final code = RecoveryCode.generate();
    final r = Random.secure();
    final salt = base64Encode(
      Uint8List.fromList([for (var i = 0; i < 16; i++) r.nextInt(256)]),
    );
    return LibraryRecoveryKey(
      code: code,
      key: await derive(code: code, salt: salt, kdf: kdf),
      salt: salt,
      kdf: kdf,
    );
  }

  /// The signing key [code] stands for, however it was typed (case and
  /// spacing are normalized as for the sync recovery code).
  static Future<LibrarySigningKey> derive({
    required String code,
    required String salt,
    required KdfParams kdf,
  }) async {
    final seed = await Keyslots.deriveKek(
      secret: RecoveryCode.normalize(code),
      salt: base64Decode(salt),
      kdf: kdf,
    );
    return LibrarySigner.fromSeed(await seed.extractBytes());
  }
}
