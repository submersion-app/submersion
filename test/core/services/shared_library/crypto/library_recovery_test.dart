import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  const fast = KdfParams(m: 1024, t: 1);

  test('a recovery code derives the same signing key', () async {
    final made = await LibraryRecovery.create(kdf: fast);
    final again = await LibraryRecovery.derive(
      code: made.code,
      salt: made.salt,
      kdf: fast,
    );
    expect(again.publicKey, made.key.publicKey);
    final messy = '  ${made.code.toUpperCase().replaceAll(' ', '   ')} ';
    final typed = await LibraryRecovery.derive(
      code: messy,
      salt: made.salt,
      kdf: fast,
    );
    expect(typed.publicKey, made.key.publicKey);
  });

  test('another code or salt derives another key', () async {
    final a = await LibraryRecovery.create(kdf: fast);
    final b = await LibraryRecovery.create(kdf: fast);
    final wrong = await LibraryRecovery.derive(
      code: b.code,
      salt: a.salt,
      kdf: fast,
    );
    expect(wrong.publicKey, isNot(a.key.publicKey));
  });

  test('the roles entry carries the public key, salt and KDF', () async {
    final made = await LibraryRecovery.create(kdf: fast);
    expect(made.toRolesJson(), {
      'publicKey': made.key.publicKey,
      'salt': made.salt,
      'kdf': fast.toJson(),
    });
  });
}
