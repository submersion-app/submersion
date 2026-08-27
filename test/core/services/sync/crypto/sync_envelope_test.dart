import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

Map<String, dynamic> _vectors() =>
    jsonDecode(
          File('test/fixtures/crypto/crypto_vectors.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Uint8List _b64(Map<String, dynamic> m, String k) =>
    base64Decode(m[k] as String);

void main() {
  final v = _vectors();

  group('SyncEnvelope', () {
    test('opens the python-built plain envelope (KAT)', () async {
      final c = v['envelopePlain'] as Map<String, dynamic>;
      final out = await SyncEnvelope.open(
        envelope: _b64(c, 'envelope'),
        dataKey: SecretKey(_b64(c, 'key')),
        expectedLibraryKeyId: c['keyId'] as String,
        filename: c['filename'] as String,
      );
      expect(out, _b64(c, 'plaintext'));
    });

    test('opens the python-built gzip envelope (KAT)', () async {
      final c = v['envelopeGzip'] as Map<String, dynamic>;
      final out = await SyncEnvelope.open(
        envelope: _b64(c, 'envelope'),
        dataKey: SecretKey(_b64(c, 'key')),
        expectedLibraryKeyId: c['keyId'] as String,
        filename: c['filename'] as String,
      );
      expect(out, _b64(c, 'plaintext'));
    });

    test(
      'seal produces byte-exact envelope with injected nonce (KAT)',
      () async {
        final c = v['envelopePlain'] as Map<String, dynamic>;
        final aes = v['aesGcm'] as Map<String, dynamic>;
        final sealed = await SyncEnvelope.seal(
          plaintext: _b64(c, 'plaintext'),
          dataKey: SecretKey(_b64(c, 'key')),
          libraryKeyId: c['keyId'] as String,
          filename: c['filename'] as String,
          compress: false,
          nonceForTest: _b64(aes, 'nonce'),
        );
        expect(sealed, _b64(c, 'envelope'));
      },
    );

    test('round-trips with compression and random nonce', () async {
      final key = SecretKey(List<int>.generate(32, (i) => 255 - i));
      final plain = Uint8List.fromList(
        utf8.encode('{"repeat":"${'ab' * 4000}"}'),
      );
      final sealed = await SyncEnvelope.seal(
        plaintext: plain,
        dataKey: key,
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        filename: 'f.json',
      );
      expect(sealed.length, lessThan(plain.length)); // gzip effective
      final opened = await SyncEnvelope.open(
        envelope: sealed,
        dataKey: key,
        expectedLibraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        filename: 'f.json',
      );
      expect(opened, plain);
    });

    test('wrong filename (AAD) fails authentication', () async {
      final c = v['envelopePlain'] as Map<String, dynamic>;
      await expectLater(
        SyncEnvelope.open(
          envelope: _b64(c, 'envelope'),
          dataKey: SecretKey(_b64(c, 'key')),
          expectedLibraryKeyId: c['keyId'] as String,
          filename: 'ssv1.devB.manifest.json',
        ),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });

    test('bit flip in ciphertext fails authentication', () async {
      final c = v['envelopePlain'] as Map<String, dynamic>;
      final tampered = Uint8List.fromList(_b64(c, 'envelope'));
      tampered[tampered.length - 1] ^= 0x01;
      await expectLater(
        SyncEnvelope.open(
          envelope: tampered,
          dataKey: SecretKey(_b64(c, 'key')),
          expectedLibraryKeyId: c['keyId'] as String,
          filename: c['filename'] as String,
        ),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });

    test(
      'keyId mismatch throws SyncEncryptionRequired with the keyId',
      () async {
        final c = v['envelopePlain'] as Map<String, dynamic>;
        await expectLater(
          SyncEnvelope.open(
            envelope: _b64(c, 'envelope'),
            dataKey: SecretKey(_b64(c, 'key')),
            expectedLibraryKeyId: '00000000-0000-0000-0000-000000000000',
            filename: c['filename'] as String,
          ),
          throwsA(
            isA<SyncEncryptionRequired>().having(
              (e) => e.libraryKeyId,
              'libraryKeyId',
              c['keyId'] as String,
            ),
          ),
        );
      },
    );

    test('hasMagic and libraryKeyIdOf', () {
      final c = v['envelopePlain'] as Map<String, dynamic>;
      final env = _b64(c, 'envelope');
      expect(SyncEnvelope.hasMagic(env), isTrue);
      expect(SyncEnvelope.hasMagic(utf8.encode('{"json":1}')), isFalse);
      expect(SyncEnvelope.libraryKeyIdOf(env), c['keyId'] as String);
      expect(
        () => SyncEnvelope.libraryKeyIdOf(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });
  });
}
