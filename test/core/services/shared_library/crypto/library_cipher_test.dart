import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  test('sealed files open only at their own path and with their key', () async {
    final c = await LibraryCipher.generate();
    final sealed = await c.seal('sites/site-s1.json', bytes('{"id":"s1"}'));
    expect(LibraryCipher.isSealed(sealed), isTrue);
    expect(LibraryCipher.keyIdOf(sealed), c.keyId.toLowerCase());
    expect(
      utf8.decode(await c.open('sites/site-s1.json', sealed)),
      '{"id":"s1"}',
    );
    await expectLater(
      c.open('sites/site-s2.json', sealed),
      throwsA(isA<EnvelopeCorruptException>()),
    );
    final other = await LibraryCipher.generate();
    await expectLater(
      other.open('sites/site-s1.json', sealed),
      throwsA(isA<LibraryLockedException>()),
    );
  });

  test('an exported key opens what the cipher sealed', () async {
    final c = await LibraryCipher.generate();
    final sealed = await c.seal('roles.json', bytes('{}'));
    final again = await LibraryCipher.fromExported(
      keyId: c.keyId,
      key: await c.exportKey(),
    );
    expect(utf8.decode(await again.open('roles.json', sealed)), '{}');
  });

  test('keyslots unlock with the passphrase or the recovery code', () async {
    const fast = KdfParams(m: 1024, t: 1);
    final c = await LibraryCipher.generate();
    final file = await c.keyslots(
      passphrase: 'correct horse battery',
      recoveryCode: 'alpha-bravo-charlie',
      kdf: fast,
    );
    expect(
      (await LibraryCipher.unlock(file, 'correct horse battery'))!.keyId,
      c.keyId,
    );
    expect(await LibraryCipher.unlock(file, 'ALPHA bravo  charlie'), isNotNull);
    expect(await LibraryCipher.unlock(file, 'wrong'), isNull);
  });
}
