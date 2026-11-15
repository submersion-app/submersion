import 'package:equatable/equatable.dart';

import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';

/// How far the dive page's tide chart reaches either side of the entry: a
/// day in all, which holds about two full tide cycles.
const diveTideWindowHalfSpan = Duration(hours: 12);

/// The predicted tide around one dive, for the dive page's chart.
///
/// Every time is a real instant, as the engine computes them; map them with
/// `siteClockConverter` (site_wall_clock.dart) for display only, so a
/// daylight-saving change inside the window cannot fold the time axis.
class DiveTideWindow extends Equatable {
  const DiveTideWindow({
    required this.entry,
    required this.start,
    required this.end,
    required this.predictions,
    required this.extremes,
  });

  /// The instant the diver entered the water.
  final DateTime entry;

  /// The first and last instants of the window.
  final DateTime start;
  final DateTime end;

  /// The tide curve, in time order.
  final List<TidePrediction> predictions;

  /// The highs and lows inside the window, in time order.
  final List<TideExtreme> extremes;

  DiveTideWindow copyWith({
    DateTime? entry,
    DateTime? start,
    DateTime? end,
    List<TidePrediction>? predictions,
    List<TideExtreme>? extremes,
  }) {
    return DiveTideWindow(
      entry: entry ?? this.entry,
      start: start ?? this.start,
      end: end ?? this.end,
      predictions: predictions ?? this.predictions,
      extremes: extremes ?? this.extremes,
    );
  }

  /// The predicted height at [instant], interpolated between the two samples
  /// around it; null outside the sampled span.
  double? heightAt(DateTime instant) {
    if (predictions.isEmpty) return null;
    if (instant.isBefore(predictions.first.time) ||
        instant.isAfter(predictions.last.time)) {
      return null;
    }
    for (var i = 1; i < predictions.length; i++) {
      final after = predictions[i];
      if (after.time.isBefore(instant)) continue;
      final before = predictions[i - 1];
      final span = after.time.difference(before.time).inMicroseconds;
      if (span <= 0) return after.heightMeters;
      final elapsed = instant.difference(before.time).inMicroseconds;
      return before.heightMeters +
          (after.heightMeters - before.heightMeters) * elapsed / span;
    }
    return predictions.first.heightMeters;
  }

  @override
  List<Object?> get props => [entry, start, end, predictions, extremes];
}

/// The tide from [halfSpan] before a dive's entry to [halfSpan] after it,
/// computed off the UI thread. [entryWallClock] is the dive's site wall
/// clock (wall-clock-as-UTC); the engine is evaluated at the real instant.
Future<DiveTideWindow> loadDiveTideWindow({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
  Duration halfSpan = diveTideWindowHalfSpan,
}) async {
  final entry = diveEntryInstant(entryWallClock, location).toUtc();
  final start = entry.subtract(halfSpan);
  final end = entry.add(halfSpan);
  // The extreme search needs a sample either side of a turn, so it looks a
  // little past each end; a high or low exactly on an end is kept. Each
  // turn's time is refined between samples, and a search started elsewhere
  // can place the same turn a few milliseconds apart, so a turn within a
  // minute of an end (the precision it is shown at) counts as inside.
  const margin = Duration(minutes: 30);
  const tolerance = Duration(minutes: 1);
  final earliest = start.subtract(tolerance);
  final latest = end.add(tolerance);
  final (predictions, found) = await (
    calculator.predictAsync(start: start, end: end),
    calculator.findExtremesAsync(
      start: start.subtract(margin),
      end: end.add(margin),
    ),
  ).wait;
  return DiveTideWindow(
    entry: entry,
    start: start,
    end: end,
    predictions: predictions,
    extremes: [
      for (final extreme in found)
        if (!extreme.time.isBefore(earliest) && !extreme.time.isAfter(latest))
          extreme,
    ],
  );
}
