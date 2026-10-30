import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/utils/off_isolate.dart';

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

  group('a large payload', () {
    final key = SecretKeyData(List.generate(32, (i) => i));
    const keyId = '12345678-1234-4567-8234-567812345678';
    const name = 'ssv1.devA.base.000000000001.p00000';
    const inline = 1 << 40;
    final nonce = List.filled(12, 7);
    final random = Random(1);
    // JSON-like, so gzip helps and still leaves a good deal to encrypt.
    final compressible = Uint8List.fromList(
      utf8.encode(
        List.generate(
          60000,
          (_) => '{"depth":${random.nextInt(1 << 30)}}',
        ).join(','),
      ),
    );
    final incompressible = Uint8List.fromList(
      List.generate(kOffIsolateMinBytes + 1024, (_) => random.nextInt(256)),
    );

    Future<Uint8List> seal(
      Uint8List plaintext, {
      bool compress = true,
      int? offIsolateMinBytes,
      OffIsolateRunner offIsolateRunner = isolateRun,
    }) => SyncEnvelope.seal(
      plaintext: plaintext,
      dataKey: key,
      libraryKeyId: keyId,
      filename: name,
      compress: compress,
      nonceForTest: nonce,
      offIsolateMinBytes: offIsolateMinBytes ?? kOffIsolateMinBytes,
      offIsolateRunner: offIsolateRunner,
    );

    Future<Uint8List> open(
      Uint8List envelope, {
      String filename = name,
      int? offIsolateMinBytes,
      OffIsolateRunner offIsolateRunner = isolateRun,
      int maxPlaintextBytes = SyncEnvelope.defaultMaxPlaintextBytes,
    }) => SyncEnvelope.open(
      envelope: envelope,
      dataKey: key,
      expectedLibraryKeyId: keyId,
      filename: filename,
      offIsolateMinBytes: offIsolateMinBytes ?? kOffIsolateMinBytes,
      offIsolateRunner: offIsolateRunner,
      maxPlaintextBytes: maxPlaintextBytes,
    );

    test('runs on the cipher the worker path is written for', () {
      expect(AesGcm.with256bits(), isA<DartAesGcm>());
    });

    test('seals through two isolates and opens through two', () async {
      var hops = 0;
      Future<R> counting<R>(FutureOr<R> Function() work) {
        hops++;
        return Isolate.run(work);
      }

      final sealed = await seal(compressible, offIsolateRunner: counting);
      expect(hops, 2, reason: 'gzip and AES-GCM');

      hops = 0;
      await open(sealed, offIsolateRunner: counting);
      expect(hops, 2, reason: 'AES-GCM and inflate');
    });

    test('inflates off-isolate once the blob could unpack large', () async {
      // Between the thresholds: small enough that gzip stays here, and a blob
      // the 256 KiB bar alone would have inflated on this isolate.
      final plain = Uint8List.sublistView(compressible, 0, 200 * 1024);
      final sealed = await seal(plain);
      final blob = sealed.length - 49;
      expect(blob, greaterThan(kOffIsolateMinBytes ~/ kCompressedCostFactor));
      expect(blob, lessThan(kOffIsolateMinBytes));

      var hops = 0;
      await open(
        sealed,
        offIsolateRunner: <R>(work) async {
          hops++;
          return Isolate.run(work);
        },
      );
      expect(hops, 2, reason: 'AES-GCM and inflate');
    });

    test('stays on this isolate below the threshold', () async {
      var hops = 0;
      Future<R> counting<R>(FutureOr<R> Function() work) {
        hops++;
        return Isolate.run(work);
      }

      final small = Uint8List.fromList(utf8.encode('{"dive":1}' * 100));
      final sealed = await seal(small, offIsolateRunner: counting);
      await open(sealed, offIsolateRunner: counting);
      expect(hops, 0);
    });

    for (final (bytes, hopsExpected) in [(40 * 1024, 1), (20 * 1024, 0)]) {
      test(
        'pure Dart AES-GCM on $bytes bytes takes $hopsExpected hops',
        () async {
          var hops = 0;
          final sealed = await seal(
            Uint8List.sublistView(incompressible, 0, bytes),
            compress: false,
            offIsolateRunner: <R>(work) async {
              hops++;
              return Isolate.run(work);
            },
          );
          expect(hops, hopsExpected);
          expect(sealed, isNotEmpty);
        },
      );
    }

    test('seals to the same bytes off-isolate as inline', () async {
      expect(
        await seal(compressible),
        await seal(compressible, offIsolateMinBytes: inline),
      );
    });

    test('opens what the inline path sealed', () async {
      final sealed = await seal(compressible, offIsolateMinBytes: inline);
      expect(await open(sealed), compressible);
    });

    test('an off-isolate seal opens inline', () async {
      final sealed = await seal(compressible);
      expect(await open(sealed, offIsolateMinBytes: inline), compressible);
    });

    test('an incompressible payload goes in raw, unflagged', () async {
      final sealed = await seal(incompressible);
      expect(sealed[20] & 0x01, 0);
      expect(await open(sealed), incompressible);
    });

    test('a wrong name still fails authentication', () async {
      final sealed = await seal(compressible);
      await expectLater(
        open(sealed, filename: 'ssv1.devB.base.000000000001.p00000'),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });

    test('a failed authentication stops before any inflate', () async {
      final sealed = await seal(compressible);
      sealed[sealed.length ~/ 2] ^= 0xff;
      var hops = 0;
      await expectLater(
        open(
          sealed,
          offIsolateRunner: <R>(work) async {
            hops++;
            return Isolate.run(work);
          },
        ),
        throwsA(isA<EnvelopeCorruptException>()),
      );
      expect(hops, 1, reason: 'it stops at AES-GCM, before any inflate');
    });

    test('the inflate cap still rejects a bomb off-isolate', () async {
      final bomb = compressZeros(gzip.encoder, mebibytes: 64);
      final sealed = await SyncEnvelope.seal(
        plaintext: bomb,
        dataKey: key,
        libraryKeyId: keyId,
        filename: name,
        compress: false,
      );
      sealed[20] |= 0x01;
      await expectLater(
        open(sealed, offIsolateMinBytes: 0, maxPlaintextBytes: 1 << 20),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    });

    test('isolates that fail give the same bytes inline', () async {
      Future<R> broken<R>(FutureOr<R> Function() work) async =>
          throw IsolateSpawnException('no isolate');

      final sealed = await seal(compressible, offIsolateRunner: broken);
      expect(sealed, await seal(compressible, offIsolateMinBytes: inline));
      expect(await open(sealed, offIsolateRunner: broken), compressible);
    });
  });
}
