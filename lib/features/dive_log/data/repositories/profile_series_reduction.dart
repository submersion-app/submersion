import 'package:flutter/foundation.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_row_decoder.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// Turns decoded series into what a reader wants.
///
/// When it runs in the background it is sent to another isolate, so it has to
/// be a top-level function, or a closure built by one such as
/// [mergedPointsReduction]. A closure written inside a repository method can
/// capture the repository along with it, and the send then fails.
typedef SeriesReduce<R> = R Function(List<ProfileSeries> series);

/// What a [SeriesReduce] produced, plus the ids of any series whose blob did
/// not decode.
///
/// The unreadable ids come back rather than being logged where they are
/// found, because the decoding may run on a background isolate and the logger
/// lives on the UI one.
typedef SeriesReduction<R> = ({R result, List<String> unreadableSeriesIds});

/// The fewest stored samples worth handing to another isolate.
///
/// The hand-off copies the blobs and waits an event-loop turn. Measured in a
/// release build on an M-series Mac, a 4,000-sample dive across two series
/// costs 6 ms to decode and merge, while an 80-sample one costs 0.1 ms against
/// 0.15 ms through an isolate, so a dive this short finishes sooner where it
/// is.
const int kInlineSeriesSampleLimit = 256;

/// Decodes [rows] and runs [reduce] over the series that read, on this
/// isolate. An unreadable blob skips its own series, as every read does.
SeriesReduction<R> reduceSeriesRows<R>(
  List<DiveProfileSeriesRow> rows,
  SeriesReduce<R> reduce,
) {
  final series = <ProfileSeries>[];
  final unreadable = <String>[];
  for (final row in rows) {
    try {
      series.add(decodeProfileSeriesRow(row));
    } on ProfileSeriesCodecException {
      unreadable.add(row.id);
    }
  }
  return (result: reduce(series), unreadableSeriesIds: unreadable);
}

/// [reduceSeriesRows] on a background isolate, unless [rows] hold fewer than
/// [kInlineSeriesSampleLimit] samples between them.
///
/// For a read of one dive. Opening a dive reads its blobs up to four times,
/// and each read of a two-computer dive took a third of a frame on the UI
/// isolate, more on a phone or a longer dive (#3820). Do not call this once
/// per dive in a bulk read: every call starts its own isolate. On the web,
/// where there are no isolates, [compute] runs the same work in place.
Future<SeriesReduction<R>> reduceSeriesRowsInBackground<R>(
  List<DiveProfileSeriesRow> rows,
  SeriesReduce<R> reduce,
) async {
  final samples = rows.fold<int>(0, (total, row) => total + row.sampleCount);
  if (samples < kInlineSeriesSampleLimit) return reduceSeriesRows(rows, reduce);
  return compute(_reduce<R>, (rows: rows, reduce: reduce));
}

SeriesReduction<R> _reduce<R>(
  ({List<DiveProfileSeriesRow> rows, SeriesReduce<R> reduce}) request,
) => reduceSeriesRows(request.rows, request.reduce);

/// Reduces series to the points a reader of the whole dive sees: the
/// superseded originals of a saved edit dropped, then every remaining
/// source's samples interleaved by timestamp.
///
/// [hasSources] and [primaryComputerId] are what [dropSupersededSeries] needs
/// to place each series in the primary family. Reading them is the caller's
/// job, which is what keeps this free of the database.
SeriesReduce<List<DiveProfilePoint>> mergedPointsReduction({
  required bool hasSources,
  required String? primaryComputerId,
}) =>
    (series) => mergeSeriesPointsCollapsingDuplicates(
      dropSupersededSeries(
        series,
        hasSources: hasSources,
        primaryComputerId: primaryComputerId,
      ),
    );
