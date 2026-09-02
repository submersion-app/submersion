import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/statistics/data/series_profile_aggregates.dart';

/// The library-wide aggregates run over packed blobs, and a library is far
/// larger than any one dive. These pin the two properties that keeps them
/// affordable: one stream is decoded at a time, and a chunk's totals can be
/// combined with another chunk's, so the caller never has to hold the whole
/// library at once either.
void main() {
  const codec = ProfileSeriesCodec();

  /// A sawtooth deep enough to register as sustained transit in both
  /// directions, so the rate aggregate has something to average.
  List<ProfileSample> sawtooth(int count) => [
    for (var i = 0; i < count; i++)
      ProfileSample(
        timestamp: i * 10,
        depth: (i % 20) < 10 ? (i % 20) * 2.0 : (20 - (i % 20)) * 2.0,
      ),
  ];

  SeriesBlob blob(String diveId, String? computerId, int samples) => SeriesBlob(
    diveId: diveId,
    computerId: computerId,
    samples: codec.encode(sawtooth(samples)).bytes,
  );

  group('per-stream folding', () {
    test('decodes one stream at a time rather than the whole library', () {
      // 100 streams of 10,000 samples. Holding every decoded ProfileSample
      // at once costs hundreds of megabytes; folding stream by stream costs
      // one stream. Asserting on memory rather than the clock is the same
      // choice bounded_inflate_test makes for the zlib bomb: decoding is
      // fast either way, so only the footprint separates the two shapes.
      final blobs = [for (var i = 0; i < 100; i++) blob('d$i', 'c1', 10000)];
      // The fixture itself is cheap: that is the point of packing.
      final packed = blobs.fold<int>(0, (n, b) => n + b.samples.length);
      expect(packed, lessThan(8 * 1024 * 1024));

      final before = ProcessInfo.currentRss;
      final totals = ascentDescentTotalsFromBlobs(blobs);
      final grew = ProcessInfo.currentRss - before;

      expect(totals.ascentCount, greaterThan(0));
      expect(
        grew,
        lessThan(128 * 1024 * 1024),
        reason: 'holding all 1,000,000 decoded samples would cost far more',
      );
    });

    test('a corrupt blob costs its own stream and no other', () {
      final good = blob('d1', 'c1', 100);
      final corrupt = SeriesBlob(
        diveId: 'd2',
        computerId: 'c1',
        samples: codec.encode(sawtooth(100)).bytes..[4] = 0xFF,
      );
      final alone = ascentDescentTotalsFromBlobs([good]);
      final withCorrupt = ascentDescentTotalsFromBlobs([good, corrupt]);
      expect(withCorrupt, alone);
    });
  });

  group('combining chunks', () {
    test('rate totals combine to the same result as one pass', () {
      final a = [blob('d1', 'c1', 400), blob('d2', 'c1', 400)];
      final b = [blob('d3', 'c1', 400)];

      final whole = ratesFromTotals(ascentDescentTotalsFromBlobs([...a, ...b]));
      final chunked = ratesFromTotals(
        combineRateTotals(
          ascentDescentTotalsFromBlobs(a),
          ascentDescentTotalsFromBlobs(b),
        ),
      );

      expect(chunked.avgAscent, closeTo(whole.avgAscent!, 1e-9));
      expect(chunked.avgDescent, closeTo(whole.avgDescent!, 1e-9));
    });

    test('depth seconds combine to the same buckets as one pass', () {
      final a = [blob('d1', 'c1', 400), blob('d2', 'c1', 400)];
      final b = [blob('d3', 'c1', 400)];

      final whole = bucketsFromSeconds(
        timeAtDepthSecondsFromBlobs([...a, ...b]),
      );
      final chunked = bucketsFromSeconds(
        combineDepthSeconds(
          timeAtDepthSecondsFromBlobs(a),
          timeAtDepthSecondsFromBlobs(b),
        ),
      );

      expect(chunked, whole);
    });

    test('an empty chunk changes nothing', () {
      final a = [blob('d1', 'c1', 400)];
      final totals = ascentDescentTotalsFromBlobs(a);
      expect(
        combineRateTotals(totals, ascentDescentTotalsFromBlobs(const [])),
        totals,
      );
      final seconds = timeAtDepthSecondsFromBlobs(a);
      expect(
        combineDepthSeconds(seconds, timeAtDepthSecondsFromBlobs(const [])),
        seconds,
      );
    });
  });

  group('agreement with the map-level reference', () {
    test('blob folding matches decoding into streams first', () {
      final blobs = [
        blob('d1', 'c1', 300),
        blob('d2', 'c1', 300),
        blob('d2', 'c2', 300),
      ];
      final streams = {
        for (final b in blobs)
          (b.diveId, b.computerId): codec.decode(b.samples),
      };

      final viaBlobs = ratesFromTotals(ascentDescentTotalsFromBlobs(blobs));
      final viaStreams = ascentDescentRates(streams);
      expect(viaBlobs.avgAscent, closeTo(viaStreams.avgAscent!, 1e-9));
      expect(viaBlobs.avgDescent, closeTo(viaStreams.avgDescent!, 1e-9));

      expect(
        bucketsFromSeconds(timeAtDepthSecondsFromBlobs(blobs)),
        timeAtDepthRanges(streams),
      );
    });

    test('two series of one stream still merge by timestamp', () {
      // The same dive and computer arriving as two rows is one stream: the
      // fold has to interleave them, not treat them as separate profiles.
      final first = SeriesBlob(
        diveId: 'd1',
        computerId: 'c1',
        samples: codec.encode([
          for (var i = 0; i < 60; i++)
            ProfileSample(timestamp: i * 20, depth: i * 0.5),
        ]).bytes,
      );
      final second = SeriesBlob(
        diveId: 'd1',
        computerId: 'c1',
        samples: codec.encode([
          for (var i = 0; i < 60; i++)
            ProfileSample(timestamp: i * 20 + 10, depth: i * 0.5 + 0.25),
        ]).bytes,
      );
      final merged = {
        ('d1', 'c1'): [
          ...codec.decode(first.samples),
          ...codec.decode(second.samples),
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      };

      expect(
        bucketsFromSeconds(timeAtDepthSecondsFromBlobs([first, second])),
        timeAtDepthRanges(merged),
      );
    });
  });
}
