import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// Models cryptography_flutter on Android (#737): the plugin auto-registers
/// itself as [Cryptography.instance], and its native HMAC rejects empty keys
/// (javax.crypto SecretKeySpec throws "Empty key"). HKDF keys its extract
/// HMAC with the salt, and the data-key salt is empty, so any derivation
/// routed through the registered instance crashes there.
class _EmptyKeyRejectingCryptography extends DartCryptography {
  @override
  Hmac hmac(HashAlgorithm hashAlgorithm) =>
      _EmptyKeyRejectingHmac(hashAlgorithm);
}

class _EmptyKeyRejectingHmac extends DartHmac {
  const _EmptyKeyRejectingHmac(super.hashAlgorithm);

  @override
  Future<Mac> calculateMac(
    List<int> bytes, {
    required SecretKey secretKey,
    List<int> nonce = const <int>[],
    List<int> aad = const <int>[],
  }) async {
    if ((await secretKey.extractBytes()).isEmpty) {
      throw ArgumentError('Empty key');
    }
    return super.calculateMac(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );
  }
}

Map<String, dynamic> _vectors() =>
    jsonDecode(
          File('test/fixtures/crypto/crypto_vectors.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  final v = _vectors();
  // Small KDF params keep the suite fast; production defaults differ.
  const fastKdf = KdfParams(m: 1024, t: 3, p: 1);

  group('Keyslots', () {
    test('Argon2id derivation matches python vector (KAT)', () async {
      final c = v['argon2id'] as Map<String, dynamic>;
      final kek = await Keyslots.deriveKek(
        secret: c['password'] as String,
        salt: base64Decode(c['salt'] as String),
        kdf: KdfParams(m: c['m'] as int, t: c['t'] as int, p: c['p'] as int),
      );
      expect(await kek.extractBytes(), base64Decode(c['output'] as String));
    });

    test('HKDF data key matches python vector (KAT)', () async {
      final c = v['hkdfData'] as Map<String, dynamic>;
      final dataKey = await Keyslots.deriveDataKey(
        SecretKey(base64Decode(c['ikm'] as String)),
      );
      expect(await dataKey.extractBytes(), base64Decode(c['output'] as String));
    });

    test('data key derivation survives an HMAC that rejects empty keys '
        '(#737 Android)', () async {
      final previous = Cryptography.instance;
      Cryptography.instance = _EmptyKeyRejectingCryptography();
      addTearDown(() => Cryptography.instance = previous);
      final c = v['hkdfData'] as Map<String, dynamic>;
      final dataKey = await Keyslots.deriveDataKey(
        SecretKey(base64Decode(c['ikm'] as String)),
      );
      expect(await dataKey.extractBytes(), base64Decode(c['output'] as String));
    });

    test('create slot then unwrap returns the MLK', () async {
      final mlk = SecretKey(List<int>.generate(32, (i) => i * 7 % 256));
      final slot = await Keyslots.createSlot(
        type: 'passphrase',
        secret: 'open sesame 42',
        mlk: mlk,
        kdf: fastKdf,
      );
      final file = KeyslotFile(
        version: 1,
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        slots: [slot],
      );
      final unwrapped = await Keyslots.tryUnwrap(
        file: file,
        secret: 'open sesame 42',
      );
      expect(await unwrapped!.extractBytes(), await mlk.extractBytes());
    });

    test('wrong secret returns null', () async {
      final mlk = SecretKey(List<int>.generate(32, (i) => i));
      final slot = await Keyslots.createSlot(
        type: 'passphrase',
        secret: 'right',
        mlk: mlk,
        kdf: fastKdf,
      );
      final file = KeyslotFile(
        version: 1,
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        slots: [slot],
      );
      expect(await Keyslots.tryUnwrap(file: file, secret: 'wrong'), isNull);
    });

    test('keyslot file JSON round-trips and matches spec shape', () async {
      final mlk = SecretKey(List<int>.generate(32, (i) => 32 - i));
      final p = await Keyslots.createSlot(
        type: 'passphrase',
        secret: 'p',
        mlk: mlk,
        kdf: fastKdf,
      );
      final r = await Keyslots.createSlot(
        type: 'recovery',
        secret: 'acid-acorn-acre-act-add-age-aid-aim',
        mlk: mlk,
        kdf: fastKdf,
      );
      final file = KeyslotFile(
        version: 1,
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        slots: [p, r],
      );
      final decoded = KeyslotFile.fromJsonBytes(file.toJsonBytes());
      expect(decoded.version, 1);
      expect(decoded.libraryKeyId, file.libraryKeyId);
      expect(decoded.slots.length, 2);
      expect(decoded.slots.first.kdf.alg, 'argon2id');
      // and the decoded copy still unlocks:
      final unwrapped = await Keyslots.tryUnwrap(file: decoded, secret: 'p');
      expect(await unwrapped!.extractBytes(), await mlk.extractBytes());
    });

    test('withReplacedSlot swaps by type', () async {
      final mlk = SecretKey(List<int>.generate(32, (i) => i));
      final p1 = await Keyslots.createSlot(
        type: 'passphrase',
        secret: 'one',
        mlk: mlk,
        kdf: fastKdf,
      );
      final p2 = await Keyslots.createSlot(
        type: 'passphrase',
        secret: 'two',
        mlk: mlk,
        kdf: fastKdf,
      );
      final file = KeyslotFile(
        version: 1,
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        slots: [p1],
      ).withReplacedSlot(p2);
      expect(file.slots.length, 1);
      expect(await Keyslots.tryUnwrap(file: file, secret: 'one'), isNull);
      expect(await Keyslots.tryUnwrap(file: file, secret: 'two'), isNotNull);
    });
  });
}
