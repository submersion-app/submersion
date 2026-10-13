import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';

void main() {
  test('a signature verifies only for its key and message', () async {
    final key = await LibrarySigner.generate();
    final other = await LibrarySigner.generate();
    final sig = await LibrarySigner.sign(key, utf8.encode('hello'));
    Future<bool> check(String pub, String msg, String? s) =>
        LibrarySigner.verify(
          publicKey: pub,
          message: utf8.encode(msg),
          signature: s,
        );
    expect(await check(key.publicKey, 'hello', sig), isTrue);
    expect(await check(key.publicKey, 'hellO', sig), isFalse);
    expect(await check(other.publicKey, 'hello', sig), isFalse);
    expect(await check(key.publicKey, 'hello', null), isFalse);
    expect(await check(key.publicKey, 'hello', 'not base64!'), isFalse);
    expect(
      await check(key.publicKey, 'hello', base64Encode([1, 2, 3])),
      isFalse,
    );
    expect(await check('not a key', 'hello', sig), isFalse);
  });

  test('a key rebuilt from its seed is the same key', () async {
    final key = await LibrarySigner.generate();
    final again = await LibrarySigner.fromSeed(base64Decode(key.privateKey));
    expect(again.publicKey, key.publicKey);
    expect(again.privateKey, key.privateKey);
  });

  test('fingerprints are four groups of four upper-case hex digits', () async {
    final key = await LibrarySigner.generate();
    final fp = LibrarySigner.fingerprint(key.publicKey);
    expect(fp, matches(RegExp(r'^[0-9A-F]{4}( [0-9A-F]{4}){3}$')));
    expect(LibrarySigner.fingerprint(key.publicKey), fp);
  });
}
