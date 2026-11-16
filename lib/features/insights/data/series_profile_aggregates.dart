import 'dart:typed_data';

import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/insights/data/depth_band_scale.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance.dart';

/// Smoothing interval used by [ascentDescentRates], in seconds.
///
/// Kept in sync with the per-dive calculator's configured target interval so
/// the two cannot drift apart on how much of a profile they smooth over. The
/// filters themselves differ: [AscentRateCalculator] takes an overlapping,
/// centred moving average over point-to-point rates (window rounded to an odd
/// count of samples, minimum three), while this aggregate averages depth into
/// fixed non-overlapping buckets and differences consecutive bucket means.
/// Both suppress the same short-timescale noise; neither is a reimplementation
/// of the other, and their per-profile outputs are close but not identical.
const int rateWindowSeconds =
    AscentRateCalculator.defaultSmoothingWindowSeconds;

/// Slowest vertical rate that counts as ascending or descending rather than
/// working a multi-level profile, in m/min.
///
/// A recreational profile spends most of its windows drifting slowly around
/// the bottom: on a representative library, windows in the 0.5-3 m/min band
/// outnumber genuine transit roughly four to one. Averaging those in drags
/// both figures down to around 2.4 m/min, which tells a diver nothing and is
/// not comparable to the ascent-rate limits they are trained against. Only
/// counting sustained movement keeps the card answering "how fast do I
/// actually go up and down".
const double sustainedTransitThreshold = 3.0;

/// How many times its own mean sample interval a profile may skip before
/// [timeAtDepthRanges] stops crediting the skip as time at that depth.
///
/// Recording gaps are real: a computer paused mid-dive, a surface interval
/// swallowed into one dive record, a profile stitched from two downloads.
/// Charging the whole pause to whichever bucket the last sample before it
/// happened to sit in would invent hours of bottom time. The bound is
/// relative to the profile's own cadence rather than an absolute number of
/// seconds because recording intervals in a real library run from 1 s to a
/// minute or more, and a manually keyed profile is sparser still. Four times
/// the mean leaves room for ordinary jitter and the occasional dropped
/// sample while cutting anything an order of magnitude larger down to size.
const int maxSampleGapFactor = 4;

typedef StreamKey = (String diveId, String? computerId);

/// One bar of the Time at depth chart. [lowerDepth] and [upperDepth] are in
/// the depth unit of the [DepthBandScale] the bucket was built with (whole
/// meters or whole feet), and [upperDepth] is null for an open-ended last
/// band.
typedef DepthBucket = ({int lowerDepth, int? upperDepth, int minutes});

/// One primary series as it crosses the isolate boundary: identity plus the
/// undecoded blob. Decoding happens on the worker.
class SeriesBlob {
  const SeriesBlob({
    required this.diveId,
    required this.computerId,
    required this.samples,
  });
  final String diveId;
  final String? computerId;
  final Uint8List samples;
}

/// Combinable running totals behind [ascentDescentRates].
///
/// The aggregate is a mean, and a mean cannot be combined across chunks;
/// its sums and counts can. Keeping them lets the caller read the library
/// a chunk of dives at a time and still get the number one pass would.
typedef RateTotals = ({
  double ascentSum,
  int ascentCount,
  double descentSum,
  int descentCount,
});

const RateTotals emptyRateTotals = (
  ascentSum: 0.0,
  ascentCount: 0,
  descentSum: 0.0,
  descentCount: 0,
);

RateTotals combineRateTotals(RateTotals a, RateTotals b) => (
  ascentSum: a.ascentSum + b.ascentSum,
  ascentCount: a.ascentCount + b.ascentCount,
  descentSum: a.descentSum + b.descentSum,
  descentCount: a.descentCount + b.descentCount,
);

({double? avgAscent, double? avgDescent}) ratesFromTotals(RateTotals t) => (
  avgAscent: t.ascentCount == 0 ? null : t.ascentSum / t.ascentCount,
  avgDescent: t.descentCount == 0 ? null : t.descentSum / t.descentCount,
);

/// Adds [b]'s seconds to [a]'s, per bucket. See [RateTotals] for why the
/// aggregates expose a combinable form at all.
Map<int, double> combineDepthSeconds(Map<int, double> a, Map<int, double> b) =>
    {
      for (final lo in {...a.keys, ...b.keys}) lo: (a[lo] ?? 0) + (b[lo] ?? 0),
    };

/// Decodes one stream at a time and hands its samples to [fold].
///
/// A library is not a dive. Decoding every blob into a map first, which is
/// what this replaced, holds every sample of every dive live at once: 100
/// streams of 10,000 samples was measured at 268 MiB retained, from 39 KiB
/// of packed blobs. Folding stream by stream leaves the previous stream's
/// samples unreachable before the next is decoded, so the peak is the
/// largest single stream however large the library is.
///
/// Blobs are grouped first because one stream can span several series rows
/// (a dive and computer whose profile arrived in two pieces); those have to
/// be interleaved before folding, or each piece would be aggregated as if
/// it were a separate profile.
///
/// One corrupt local blob (a decode failure the writer never should have
/// let through, but storage can still bit-rot) is skipped rather than
/// failing the whole aggregate: every other blob's samples still
/// contribute, so one bad row blanks only its own stream instead of every
/// chart on the dive.
void _forEachStream(
  List<SeriesBlob> blobs,
  void Function(StreamKey key, List<ProfileSample> samples) fold,
) {
  const codec = ProfileSeriesCodec();
  final byStream = <StreamKey, List<SeriesBlob>>{};
  for (final b in blobs) {
    byStream.putIfAbsent((b.diveId, b.computerId), () => []).add(b);
  }
  for (final MapEntry(key: key, value: rows) in byStream.entries) {
    List<ProfileSample>? samples;
    for (final b in rows) {
      final List<ProfileSample> decoded;
      try {
        decoded = codec.decode(b.samples);
      } on ProfileSeriesCodecException {
        continue;
      }
      samples = samples == null
          ? decoded
          : _mergedByTimestamp(samples, decoded);
    }
    if (samples == null) continue;
    fold(key, samples);
    // samples falls out of scope here, before the next stream is decoded.
  }
}

/// [ascentDescentRates] over packed blobs, as combinable totals.
RateTotals ascentDescentTotalsFromBlobs(List<SeriesBlob> blobs) {
  var totals = emptyRateTotals;
  _forEachStream(blobs, (_, samples) {
    totals = _foldRates(totals, samples);
  });
  return totals;
}

/// [timeAtDepthRanges] over packed blobs, as combinable seconds keyed by
/// [scale]'s band index.
Map<int, double> timeAtDepthSecondsFromBlobs(
  List<SeriesBlob> blobs, {
  DepthBandScale scale = DepthBandScale.metric,
}) {
  final seconds = <int, double>{};
  _forEachStream(
    blobs,
    (_, samples) => _foldDepthSeconds(seconds, samples, scale),
  );
  return seconds;
}

/// Each dive's vertical distance from its primary series (issue #4569),
/// keyed by dive id; see [verticalDistanceMeters].
///
/// A stream stored as several series rows is interleaved first, so it counts
/// once. A dive logged by two primary computers keeps the larger figure: both
/// recorded the same dive, and the larger one missed less of it. A dive whose
/// every blob fails to decode is absent, so the caller falls back to its max
/// depth.
Map<String, double> verticalDistanceByDiveFromBlobs(List<SeriesBlob> blobs) {
  final out = <String, double>{};
  _forEachStream(blobs, (key, samples) {
    final meters = verticalDistanceMeters(samples.map((s) => s.depth));
    final previous = out[key.$1];
    if (previous == null || meters > previous) out[key.$1] = meters;
  });
  return out;
}

({double? avgAscent, double? avgDescent}) ascentDescentRatesFromBlobs(
  List<SeriesBlob> blobs,
) => ratesFromTotals(ascentDescentTotalsFromBlobs(blobs));

List<DepthBucket> timeAtDepthRangesFromBlobs(
  List<SeriesBlob> blobs, {
  DepthBandScale scale = DepthBandScale.metric,
}) => bucketsFromSeconds(
  timeAtDepthSecondsFromBlobs(blobs, scale: scale),
  scale: scale,
);

/// Stable interleave of two timestamp-ordered lists (two series of one
/// stream, in stored order for a timestamp tie).
///
/// "Stored order" here is `ProfileSeriesRepository.getRowsForDives`'s
/// `(diveId, startTimestamp, id)` ordering: [a] and [b] arrive from that
/// query already sorted, so a tie always breaks on series id rather than on
/// insertion order or scan order, which is what makes the merged result the
/// same on every device regardless of which one produced it.
List<ProfileSample> _mergedByTimestamp(
  List<ProfileSample> a,
  List<ProfileSample> b,
) {
  final out = <ProfileSample>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (b[j].timestamp < a[i].timestamp) {
      out.add(b[j++]);
    } else {
      out.add(a[i++]);
    }
  }
  out.addAll(a.sublist(i));
  out.addAll(b.sublist(j));
  return out;
}

/// The legacy SQL, in Dart: per stream, samples fall into windows of
/// [rateWindowSeconds] by `timestamp ~/ rateWindowSeconds`; each window
/// contributes its mean depth and mean timestamp; consecutive windows (in
/// window order) give `rate = (prevDepth - depth) * 60 / (at - prevAt)` when
/// `at > prevAt`; ascents average the rates at or above the threshold,
/// descents the rates at or below its negative (negated).
///
/// Assumes each stream's samples are already sorted by timestamp.
({double? avgAscent, double? avgDescent}) ascentDescentRates(
  Map<StreamKey, List<ProfileSample>> samplesByStream,
) {
  var totals = emptyRateTotals;
  for (final samples in samplesByStream.values) {
    totals = _foldRates(totals, samples);
  }
  return ratesFromTotals(totals);
}

/// One stream's contribution to the rate totals. Summing rate by rate in
/// stream order, rather than collecting every rate and averaging at the
/// end, is what lets a caller fold a stream and drop its samples.
RateTotals _foldRates(RateTotals totals, List<ProfileSample> samples) {
  final windows = <int, ({double depthSum, double atSum, int n})>{};
  for (final s in samples) {
    final index = s.timestamp ~/ rateWindowSeconds;
    final w = windows[index];
    windows[index] = w == null
        ? (depthSum: s.depth, atSum: s.timestamp.toDouble(), n: 1)
        : (
            depthSum: w.depthSum + s.depth,
            atSum: w.atSum + s.timestamp,
            n: w.n + 1,
          );
  }
  final ordered = windows.keys.toList()..sort();
  var ascentSum = totals.ascentSum;
  var ascentCount = totals.ascentCount;
  var descentSum = totals.descentSum;
  var descentCount = totals.descentCount;
  double? prevDepth;
  double? prevAt;
  for (final index in ordered) {
    final w = windows[index]!;
    final depth = w.depthSum / w.n;
    final at = w.atSum / w.n;
    if (prevAt != null && at > prevAt) {
      final rate = (prevDepth! - depth) * 60.0 / (at - prevAt);
      if (rate >= sustainedTransitThreshold) {
        ascentSum += rate;
        ascentCount++;
      }
      if (rate <= -sustainedTransitThreshold) {
        descentSum += -rate;
        descentCount++;
      }
    }
    prevDepth = depth;
    prevAt = at;
  }
  return (
    ascentSum: ascentSum,
    ascentCount: ascentCount,
    descentSum: descentSum,
    descentCount: descentCount,
  );
}

/// The legacy SQL, in Dart: per stream with more than one sample, the cadence
/// cap is `(maxAt - minAt) * maxSampleGapFactor / (n - 1)`; each interval to
/// the next sample (in stored order after the timestamp sort) is banded by
/// its start depth ([DepthBandScale.bandOf]) and contributes
/// `min(seconds, cap)` when `seconds > 0`. Buckets come back as
/// [bucketsFromSeconds] shapes them.
///
/// Assumes each stream's samples are already sorted by timestamp, with ties
/// in stored order.
List<DepthBucket> timeAtDepthRanges(
  Map<StreamKey, List<ProfileSample>> samplesByStream, {
  DepthBandScale scale = DepthBandScale.metric,
}) {
  final seconds = <int, double>{};
  for (final samples in samplesByStream.values) {
    _foldDepthSeconds(seconds, samples, scale);
  }
  return bucketsFromSeconds(seconds, scale: scale);
}

/// Adds one stream's intervals to [seconds], keyed by [scale]'s band index.
void _foldDepthSeconds(
  Map<int, double> seconds,
  List<ProfileSample> samples,
  DepthBandScale scale,
) {
  if (samples.length < 2) return;
  final minAt = samples.first.timestamp;
  final maxAt = samples.last.timestamp;
  final cap = (maxAt - minAt) * maxSampleGapFactor / (samples.length - 1.0);
  for (var i = 0; i + 1 < samples.length; i++) {
    final gap = samples[i + 1].timestamp - samples[i].timestamp;
    if (gap <= 0) continue;
    final depth = samples[i].depth;
    // A sample with no usable depth (a corrupt import) says nothing about
    // where the diver was, and flooring it would throw.
    if (!depth.isFinite) continue;
    final band = scale.bandOf(depth);
    seconds[band] = (seconds[band] ?? 0) + (gap < cap ? gap.toDouble() : cap);
  }
}

/// The bars a [timeAtDepthSecondsFromBlobs] total describes (issue #4600):
/// one per band from the surface down to the deepest band holding at least
/// a rounded minute, so a band nobody dived in above it still shows, as zero,
/// and the depth axis stays continuous.
///
/// No more than [maxBars] come back. When time sits deeper than the last of
/// them, that last bar takes all of it and turns open-ended ([upperDepth]
/// null). Its minutes are rounded from the summed seconds, not summed from
/// rounded minutes, so several slivers of deep time are not each rounded
/// away.
///
/// Bars at the deep end that round to no minutes are left off: a depth
/// spike a few seconds long, common in recorded profiles, would otherwise
/// stretch the chart with bars reading 0. The first bar always stays.
List<DepthBucket> bucketsFromSeconds(
  Map<int, double> seconds, {
  DepthBandScale scale = DepthBandScale.metric,
  int maxBars = timeAtDepthMaxBars,
}) {
  if (seconds.isEmpty) return const [];
  final deepest = seconds.keys.reduce((a, b) => a > b ? a : b);
  final capped = deepest >= maxBars;
  final last = capped ? maxBars - 1 : deepest;
  double secondsAt(int band) {
    if (!capped || band < last) return seconds[band] ?? 0;
    var total = 0.0;
    for (final entry in seconds.entries) {
      if (entry.key >= last) total += entry.value;
    }
    return total;
  }

  final bars = <DepthBucket>[
    for (var band = 0; band <= last; band++)
      (
        lowerDepth: band * scale.step,
        upperDepth: capped && band == last ? null : (band + 1) * scale.step,
        minutes: (secondsAt(band) / 60).round(),
      ),
  ];
  var length = bars.length;
  while (length > 1 && bars[length - 1].minutes == 0) {
    length--;
  }
  return bars.sublist(0, length);
}
