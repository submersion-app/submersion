import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';

import '../../support/compression_bombs.dart';

void main() {
  Uint8List gz(List<int> body) => Uint8List.fromList(gzip.encode(body));
  Uint8List zl(List<int> body) => Uint8List.fromList(zlib.encode(body));

  group('inflateBounded', () {
    test('returns the body of a gzip stream under the cap', () {
      final body = List<int>.generate(5000, (i) => i % 251);
      expect(
        inflateBounded(
          gz(body),
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 1 << 20,
        ),
        body,
      );
    });

    test('returns the body of a zlib stream under the cap', () {
      // The decoder is a parameter so the same guard covers both framings:
      // sync envelopes are gzip, the profile series codecs are zlib.
      final body = List<int>.generate(5000, (i) => i % 251);
      expect(
        inflateBounded(
          zl(body),
          decoder: zlib.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 1 << 20,
        ),
        body,
      );
    });

    test('accepts a body of exactly maxBytes', () {
      final body = List<int>.filled(4096, 9);
      expect(
        inflateBounded(
          gz(body),
          decoder: gzip.decoder,
          maxBytes: 4096,
          maxBlobBytes: 1 << 20,
        ),
        hasLength(4096),
      );
    });

    test('refuses a body one byte over maxBytes', () {
      final body = List<int>.filled(4097, 9);
      expect(
        () => inflateBounded(
          gz(body),
          decoder: gzip.decoder,
          maxBytes: 4096,
          maxBlobBytes: 1 << 20,
        ),
        throwsA(
          isA<BoundedInflateException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the 4096 byte'),
          ),
        ),
      );
    });

    test('refuses a gzip bomb without inflating it whole', () {
      // Half a gigabyte of zeros, gzipped a mebibyte at a time so the
      // fixture itself never costs half a gigabyte. Asserting on memory
      // rather than the clock is deliberate: the inflater gets through this
      // in well under a second, so a time bound cannot tell a chunked abort
      // from a decoder that buffered the lot and checked its length
      // afterwards.
      final bomb = compressZeros(gzip.encoder, mebibytes: 512);
      expect(bomb.length, lessThan(1 << 20));

      final before = ProcessInfo.currentRss;
      expect(
        () => inflateBounded(
          bomb,
          decoder: gzip.decoder,
          maxBytes: 64 * 1024,
          maxBlobBytes: 1 << 20,
        ),
        throwsA(isA<BoundedInflateException>()),
      );
      final grew = ProcessInfo.currentRss - before;
      // Buffering the whole body would need 512 MiB. The threshold is loose
      // enough for GC noise and still far under that.
      expect(grew, lessThan(64 * 1024 * 1024));
    });

    test('refuses a blob longer than maxBlobBytes', () {
      // Checked before the conversion: the filter copies the whole input
      // natively before it emits a first chunk, so a sink-side check never
      // sees an oversized blob.
      final padded = Uint8List(4096)..setRange(0, 8, gz([1, 2, 3]));
      expect(
        () => inflateBounded(
          padded,
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 512,
        ),
        throwsA(
          isA<BoundedInflateException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the 512 allowed'),
          ),
        ),
      );
    });

    test('does not treat the decoder argument as a framing check', () {
      // Dart's gzip decoder sniffs the header, so it reads a zlib stream
      // too. Pinned because the parameter name suggests otherwise: it
      // selects an intent, not a guarantee about what arrived, and a caller
      // that needs to know which framing it was handed must check itself.
      final body = utf8.encode('zlib body read by the gzip decoder');
      expect(
        inflateBounded(
          zl(body),
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 1 << 20,
        ),
        body,
      );
    });

    test('refuses bytes that are not a compressed stream', () {
      expect(
        () => inflateBounded(
          Uint8List.fromList([1, 2, 3, 4, 5]),
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 1 << 20,
        ),
        throwsA(
          isA<BoundedInflateException>().having(
            (e) => e.message,
            'message',
            contains('not a valid compressed stream'),
          ),
        ),
      );
    });

    test('returns an empty body for empty input', () {
      // Both framings accept zero bytes as zero output rather than as
      // corruption. Ruling on an empty body is the caller's job, not the
      // inflater's.
      expect(
        inflateBounded(
          Uint8List(0),
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: 1 << 20,
        ),
        isEmpty,
      );
    });

    test('a truncated stream returns a short body rather than throwing', () {
      // Pinned, not endorsed: the inflater reports no error for a lost tail,
      // and dropping only the CRC/length trailer returns the body in full,
      // so the checksum is never verified. Callers must frame their own
      // payload; a sync envelope does, because AES-GCM authenticates the
      // compressed bytes before they ever reach here.
      final full = gz(List<int>.generate(300, (i) => i % 251));
      Uint8List inflate(Uint8List b) => inflateBounded(
        b,
        decoder: gzip.decoder,
        maxBytes: 1 << 20,
        maxBlobBytes: 1 << 20,
      );
      expect(inflate(full.sublist(0, full.length ~/ 2)), hasLength(133));
      expect(inflate(full.sublist(0, full.length - 4)), hasLength(300));
    });

    test('names itself and its cause when it lands in a log', () {
      // toString is what a bare log line shows, so it has to carry both the
      // type and the reason. Callers that wrap this (SyncEnvelope.open) pass
      // `message` on rather than the exception, so the reason survives
      // without a second type prefix in front of it.
      expect(
        const BoundedInflateException(
          'inflated body exceeds 4096 byte(s)',
        ).toString(),
        'BoundedInflateException: inflated body exceeds 4096 byte(s)',
      );
    });

    test('lets a programming error surface instead of wrapping it', () {
      expect(
        () => inflateBounded(
          gz([1, 2, 3]),
          decoder: gzip.decoder,
          maxBytes: -1,
          maxBlobBytes: 1 << 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => inflateBounded(
          gz([1, 2, 3]),
          decoder: gzip.decoder,
          maxBytes: 1 << 20,
          maxBlobBytes: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
