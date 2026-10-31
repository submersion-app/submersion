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

/// What a [SeriesReduce] produced, plus why each series whose blob did not
/// decode failed, keyed by series id.
///
/// The failures come back rather than being logged where they are found,
/// because the decoding may run on a background isolate and the logger lives
/// on the UI one.
typedef SeriesReduction<R> = ({R result, Map<String, String> unreadable});

/// The fewest stored samples worth handing to another isolate.
///
/// The hand-off copies the blobs and waits an event-loop turn, so it always
/// takes longer overall; what it buys is a UI isolate that keeps painting.
/// Measured in an AOT build on an M-series Mac, a 4,000-sample dive across
/// two series costs 6 ms to decode and merge, and 580 samples 0.7 ms. Below
/// this limit a read stalls the UI isolate for about 0.3 ms, which is not
/// worth the extra wait even on a slower phone.
const int kInlineSeriesSampleLimit = 256;

/// Decodes [rows] and runs [reduce] over the series that read, on this
/// isolate. An unreadable blob skips its own series, as every read does.
SeriesReduction<R> reduceSeriesRows<R>(
  List<DiveProfileSeriesRow> rows,
  SeriesReduce<R> reduce,
) {
  final series = <ProfileSeries>[];
  final unreadable = <String, String>{};
  for (final row in rows) {
    try {
      series.add(decodeProfileSeriesRow(row));
    } on ProfileSeriesCodecException catch (e) {
      unreadable[row.id] = '$e';
    }
  }
  return (result: reduce(series), unreadable: unreadable);
}

/// [reduceSeriesRows] on a background isolate, unless [rows] hold fewer than
/// [kInlineSeriesSampleLimit] samples between them.
///
/// Opening a dive reads its blobs up to four times, and each read of a
/// two-computer dive took a third of a frame on the UI isolate, more on a
/// phone or a longer dive (#3820). Do not run this for many dives at once:
/// every call starts its own isolate, so a bulk read passes all its rows to
/// one call. On the web, where there are no isolates, [compute] runs the same
/// work in place.
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
