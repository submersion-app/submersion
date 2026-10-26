import 'package:flutter/foundation.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_row_decoder.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// Downsampled depth profiles for the dive list's mini charts, keyed by dive
/// id, plus the ids of any series whose blob did not decode.
///
/// The unreadable ids come back rather than being logged where they are
/// found, because the summarising runs on a background isolate and the
/// logger lives on the UI one.
typedef SparklineSummaries = ({
  Map<String, List<DiveProfilePoint>> byDive,
  List<String> unreadableSeriesIds,
});

/// [summarizeSparklines] on a background isolate.
///
/// A page of the dive list carries up to 50 full-resolution blobs, and
/// decoding, merging and downsampling them on the UI isolate cost 14 to 45 ms
/// in a debug build, landing mid-fling as one to three dropped frames per
/// page (#3506). On the web, where there are no isolates, [compute] runs the
/// same work in place.
Future<SparklineSummaries> summarizeSparklinesInBackground(
  List<DiveProfileSeriesRow> rows, {
  required int maxSamples,
}) {
  if (rows.isEmpty) {
    return Future.value((
      byDive: const <String, List<DiveProfilePoint>>{},
      unreadableSeriesIds: const <String>[],
    ));
  }
  return compute(_summarize, (rows: rows, maxSamples: maxSamples));
}

SparklineSummaries _summarize(
  ({List<DiveProfileSeriesRow> rows, int maxSamples}) request,
) => summarizeSparklines(request.rows, maxSamples: request.maxSamples);

/// Summarises each dive in [rows] to at most [maxSamples] points.
///
/// [rows] must be grouped by dive and ordered within each dive as
/// `ProfileSeriesRepository.getRowsForDives` returns them. A dive whose every
/// series is unreadable, or that has none, is absent from the result. Uses
/// the dive's primary series when it has any, every series otherwise
/// ([_sparklineSeries]).
SparklineSummaries summarizeSparklines(
  List<DiveProfileSeriesRow> rows, {
  required int maxSamples,
}) {
  final byDive = <String, List<ProfileSeries>>{};
  final unreadable = <String>[];
  for (final row in rows) {
    final ProfileSeries series;
    try {
      series = decodeProfileSeriesRow(row);
    } on ProfileSeriesCodecException {
      unreadable.add(row.id);
      continue;
    }
    byDive.putIfAbsent(row.diveId, () => []).add(series);
  }
  return (
    byDive: {
      for (final entry in byDive.entries)
        entry.key: _downsample([
          for (final p in mergeSeriesPoints(_sparklineSeries(entry.value)))
            DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
        ], maxSamples),
    },
    unreadableSeriesIds: unreadable,
  );
}

/// The series a sparkline summarises: the primary ones when the dive has
/// any, every series otherwise.
///
/// A demoted series is either a consolidated secondary computer's copy of
/// the dive or the originals a saved edit superseded. Interleaving either
/// with the primary drew the mini chart as a sawtooth between two
/// computers' depths (#543). With a primary present this matches
/// `getDiveProfile`'s `primaryOnly` read, so the mini chart and the lazily
/// loaded list profile show the same shape. The two deliberately differ
/// when NO series is primary (none promoted yet): that read returns an
/// empty list, while a sparkline is better drawn from whatever exists
/// than left blank, so every series contributes here.
List<ProfileSeries> _sparklineSeries(List<ProfileSeries> series) {
  final primary = [
    for (final s in series)
      if (s.isPrimary) s,
  ];
  return primary.isEmpty ? series : primary;
}

/// Evenly spaces [points] down to at most [maxSamples], keeping the first
/// and last point. Returns [points] unchanged when already short enough.
List<DiveProfilePoint> _downsample(
  List<DiveProfilePoint> points,
  int maxSamples,
) {
  if (points.length <= maxSamples) return points;
  return [
    for (var i = 0; i < maxSamples; i++)
      points[(i * (points.length - 1)) ~/ (maxSamples - 1)],
  ];
}
