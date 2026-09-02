import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

import '../../../../support/compression_bombs.dart';

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

  group('SyncEnvelope payload size cap', () {
    final key = SecretKey(List<int>.generate(32, (i) => i));
    const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

    test('the cap clears the only structurally bounded payload', () {
      // Base parts are sliced to exactly BaseChunker.defaultPartSize, so a
      // 648 MB library publishes as 78 identical 8 MiB envelopes rather
      // than one large one. Anchoring the cap to that constant keeps the
      // relationship visible if either moves.
      expect(
        SyncEnvelope.defaultMaxPlaintextBytes,
        greaterThanOrEqualTo(BaseChunker.defaultPartSize * 32),
      );
    });

    test('open refuses a gzip bomb inside an authentic envelope', () async {
      // Sealed with the real key, so this is the in-trust-boundary case the
      // cap exists for: a malicious or buggy peer, or a compromised device.
      // The gzip flag lives at header offset 20, outside both the ciphertext
      // and the AAD, so setting it after sealing leaves authentication
      // intact, which is exactly how an attacker reaches gzip.decode.
      final bomb = compressZeros(gzip.encoder, mebibytes: 512);
      // The cap below has to clear the compressed blob, because open fuses
      // maxBlobBytes to it. Sized under it, the pre-conversion blob guard
      // fires and nothing is ever inflated, which would leave the chunked
      // abort (the whole point of the fix) untested at this layer.
      expect(bomb.length, lessThan(1 << 20));
      final envelope = await SyncEnvelope.seal(
        plaintext: bomb,
        dataKey: key,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.cs.000000000001.json',
        compress: false,
      );
      envelope[20] |= 0x01;

      final before = ProcessInfo.currentRss;
      await expectLater(
        SyncEnvelope.open(
          envelope: envelope,
          dataKey: key,
          expectedLibraryKeyId: keyId,
          filename: 'ssv1.devA.cs.000000000001.json',
          maxPlaintextBytes: 1 << 20,
        ),
        throwsA(
          isA<EnvelopeCorruptException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('inflated body exceeds'),
              // The reason is passed through, not the exception: a nested
              // 'BoundedInflateException:' prefix here would mean open
              // interpolated the error object instead of its message.
              isNot(contains('BoundedInflateException')),
            ),
          ),
        ),
      );
      // Buffering the whole body would need 512 MiB. Loose enough for GC
      // noise and still far under that.
      expect(ProcessInfo.currentRss - before, lessThan(64 * 1024 * 1024));
    });

    test('open refuses a flipped gzip flag rather than leaking a raw '
        'FormatException', () async {
      // An attacker with no key can still flip the unauthenticated flag
      // byte. That turns plaintext into "not a gzip stream", which used to
      // escape as dart:io's FormatException: a type no caller can classify,
      // so ChangesetReader's `on EnvelopeCorruptException` break could not
      // see it and the failure fell through to the per-peer catch instead.
      final envelope = await SyncEnvelope.seal(
        plaintext: Uint8List.fromList(utf8.encode('{"not":"gzip"}')),
        dataKey: key,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.manifest.json',
        compress: false,
      );
      envelope[20] |= 0x01;

      await expectLater(
        SyncEnvelope.open(
          envelope: envelope,
          dataKey: key,
          expectedLibraryKeyId: keyId,
          filename: 'ssv1.devA.manifest.json',
        ),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });

    test('an uncompressed payload over the cap still opens', () async {
      // The cap bounds inflation, not the file: a payload with no gzip flag
      // was never amplified, so refusing it would only strand data.
      final plain = Uint8List.fromList(
        List<int>.generate(8192, (i) => i % 251),
      );
      final envelope = await SyncEnvelope.seal(
        plaintext: plain,
        dataKey: key,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.base.000000000001.p0000',
        compress: false,
      );
      expect(
        await SyncEnvelope.open(
          envelope: envelope,
          dataKey: key,
          expectedLibraryKeyId: keyId,
          filename: 'ssv1.devA.base.000000000001.p0000',
          maxPlaintextBytes: 1024,
        ),
        plain,
      );
    });

    test('seal stores a payload over the cap uncompressed so it can be '
        'read back', () async {
      // A device must never write an envelope it would itself refuse.
      // Degrading to uncompressed keeps the write path total: the upload is
      // larger, but nothing is stranded, which is the safer half of the
      // trade for a payload this size.
      final plain = Uint8List.fromList(
        utf8.encode('{"repeat":"${'ab' * 4000}"}'),
      );
      final envelope = await SyncEnvelope.seal(
        plaintext: plain,
        dataKey: key,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.cs.000000000002.json',
        maxPlaintextBytes: 1024,
      );
      expect(envelope[20] & 0x01, 0, reason: 'gzip flag must not be set');
      expect(
        await SyncEnvelope.open(
          envelope: envelope,
          dataKey: key,
          expectedLibraryKeyId: keyId,
          filename: 'ssv1.devA.cs.000000000002.json',
          maxPlaintextBytes: 1024,
        ),
        plain,
      );
    });

    test('seal still compresses a payload under the cap', () async {
      final plain = Uint8List.fromList(
        utf8.encode('{"repeat":"${'ab' * 4000}"}'),
      );
      final envelope = await SyncEnvelope.seal(
        plaintext: plain,
        dataKey: key,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.cs.000000000003.json',
        maxPlaintextBytes: 1 << 20,
      );
      expect(envelope[20] & 0x01, 0x01, reason: 'gzip flag must be set');
      expect(envelope.length, lessThan(plain.length));
    });
  });
}
