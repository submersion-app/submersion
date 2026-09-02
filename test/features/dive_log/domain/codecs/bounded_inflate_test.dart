import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/bounded_inflate.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

void main() {
  final zlibCodec = ZLibCodec(level: 6);

  Uint8List deflate(List<int> body) =>
      Uint8List.fromList(zlibCodec.encode(body));

  group('inflateBounded', () {
    test('returns the body of a stream under the cap', () {
      final body = List<int>.generate(5000, (i) => i % 251);
      expect(inflateBounded(deflate(body), maxBytes: 1 << 20), body);
    });

    test('accepts a body of exactly maxBytes', () {
      final body = List<int>.filled(4096, 9);
      expect(inflateBounded(deflate(body), maxBytes: 4096), hasLength(4096));
    });

    test('refuses a body one byte over maxBytes', () {
      final body = List<int>.filled(4097, 9);
      expect(
        () => inflateBounded(deflate(body), maxBytes: 4096),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the 4096 byte'),
          ),
        ),
      );
    });

    test('refuses a zlib bomb without inflating it whole', () {
      // A gigabyte of zeros, deflated a mebibyte at a time so the fixture
      // itself never costs a gigabyte. Asserting on memory rather than the
      // clock is deliberate: zlib inflates a gigabyte in well under a
      // second, so a time bound cannot tell a chunked abort from a decoder
      // that buffered the lot and checked its length afterwards.
      final bomb = _deflateZeros(mebibytes: 1024);
      expect(bomb.length, lessThan(2 << 20));

      final before = ProcessInfo.currentRss;
      expect(
        () => inflateBounded(bomb, maxBytes: 64 * 1024),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
      final grew = ProcessInfo.currentRss - before;
      // Buffering the whole body would need 1 GiB. The threshold is loose
      // enough for GC noise and still an order of magnitude under that.
      expect(grew, lessThan(128 * 1024 * 1024));
    });

    test('refuses a blob longer than maxBlobBytes', () {
      // Bytes after a complete zlib stream are copied into the native
      // filter and then discarded, so without this cap an arbitrarily long
      // pad drives peak memory and still returns a body and no error.
      final padded = Uint8List(4096)..setRange(0, 8, deflate([1, 2, 3]));
      expect(
        () => inflateBounded(padded, maxBlobBytes: 512),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the 512 allowed'),
          ),
        ),
      );
    });

    test('the blob cap cannot refuse what the body cap would accept', () {
      // Deflate never expands a body past the stream overhead, so matching
      // the two caps adds no false refusal.
      expect(kMaxSeriesBlobBytes, greaterThanOrEqualTo(kMaxSeriesBodyBytes));
    });

    test('a truncated stream returns a short body rather than throwing', () {
      // Pinned, not endorsed: zlib reports no error for a lost tail, and
      // dropping only the adler-32 trailer returns the body in full, so the
      // checksum is never verified. The codecs catch this downstream by
      // requiring the column blocks to span the body exactly.
      final full = deflate(List<int>.generate(300, (i) => i % 251));
      expect(inflateBounded(full.sublist(0, full.length ~/ 2)), hasLength(135));
      expect(inflateBounded(full.sublist(0, full.length - 4)), hasLength(300));
    });

    test('refuses bytes that are not a zlib stream', () {
      expect(
        () => inflateBounded(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('not a zlib stream'),
          ),
        ),
      );
    });

    test('returns an empty body for empty input', () {
      // zlib accepts zero bytes as zero output rather than as corruption.
      // Ruling on an empty body is the codecs' job, not the inflater's.
      expect(inflateBounded(Uint8List(0)), isEmpty);
    });

    test('lets a programming error surface instead of wrapping it', () {
      expect(
        () => inflateBounded(deflate([1, 2, 3]), maxBytes: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('limits', () {
    test('the body cap comfortably clears a maximal profile series', () {
      // A maximal series is kMaxSeriesSampleCount samples at roughly 140
      // uncompressed bytes each. The body cap is the outer bound against
      // unbounded inflation, so it must sit above that with headroom, not
      // on it: refusing a legitimate series means unreadable stored data.
      const maximalBody = kMaxSeriesSampleCount * 140;
      expect(kMaxSeriesBodyBytes, greaterThan(maximalBody));
    });

    test('the sample cap is the guard that binds for profiles', () {
      // 28 columns of references alone is 8 bytes per sample per column,
      // and the boxed values, presence lists and ProfileSample objects cost
      // several times that again. If the body cap ever bound first, this
      // arithmetic would stop describing the real ceiling.
      expect(kMaxSeriesSampleCount * 28 * 8, lessThan(kMaxSeriesBodyBytes * 4));
    });
  });
}

/// Deflates [mebibytes] MiB of zeros without ever holding them.
Uint8List _deflateZeros({required int mebibytes}) {
  final chunks = <List<int>>[];
  final sink = ZLibCodec(
    level: 6,
  ).encoder.startChunkedConversion(_Collect(chunks));
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < mebibytes; i++) {
    sink.add(block);
  }
  sink.close();
  return Uint8List.fromList([for (final c in chunks) ...c]);
}

class _Collect implements Sink<List<int>> {
  _Collect(this.chunks);

  final List<List<int>> chunks;

  @override
  void add(List<int> data) => chunks.add(data);

  @override
  void close() {}
}
