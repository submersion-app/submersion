import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';

/// Assumed duration when a dive has neither runtime nor bottom time.
const Duration _fallbackDuration = Duration(minutes: 45);

/// Minimum visual width so very short dives stay tappable/visible.
const double _minWidthFraction = 0.02;

/// One dive rendered as a block on a 24h day axis.
class RhythmBlock extends Equatable {
  final double startFraction;
  final double widthFraction;

  /// The whole dive was in darkness: the Night bucket of the Time patterns
  /// classifier, so the trip story and Insights agree on what night is.
  final bool isNight;

  const RhythmBlock({
    required this.startFraction,
    required this.widthFraction,
    required this.isNight,
  });

  @override
  List<Object?> get props => [startFraction, widthFraction, isNight];
}

/// Lay out one day's dives on a 24h axis as fractions of the day.
///
/// Position is derived from each dive's wall-clock time of day (hour/minute/
/// second), not `difference()` from midnight: the latter measures elapsed
/// physical time and would shift by an hour across a DST boundary. Dive times
/// are wall-clock-as-UTC in this codebase, so the components are the truth.
/// This is why the day's date isn't needed — dives are already grouped into
/// their calendar day upstream, and only the time-of-day matters here.
///
/// Night is decided by [TimeOfDayClassifier] against sunrise and sunset at
/// the dive site, with the same exit time and fallback clock times as the
/// Time patterns chart.
List<RhythmBlock> computeRhythmBlocks(List<Dive> dives) {
  const daySeconds = 24 * 3600;
  final classifier = TimeOfDayClassifier();

  return dives.map((dive) {
    final entry = dive.entryTime ?? dive.dateTime;
    // The exit as `diveExitMillisSql` reads it for the Time patterns chart:
    // the stored exit when it is after the entry, else entry plus runtime.
    // The block is drawn to the same exit that decides night.
    final storedExit = dive.exitTime;
    final runtime = dive.effectiveRuntime;
    final exit = storedExit != null && storedExit.isAfter(entry)
        ? storedExit
        : (runtime == null ? null : entry.add(runtime));
    final duration = exit?.difference(entry) ?? _fallbackDuration;

    final startSeconds = entry.hour * 3600 + entry.minute * 60 + entry.second;
    var start = (startSeconds / daySeconds).clamp(0.0, 1.0);
    var width = (duration.inSeconds / daySeconds).clamp(_minWidthFraction, 1.0);
    if (start + width > 1.0) {
      width = 1.0 - start;
      if (width < _minWidthFraction) {
        start = 1.0 - _minWidthFraction;
        width = _minWidthFraction;
      }
    }

    final location = dive.site?.location;
    final bucket = classifier
        .classify(
          entry: entry,
          exit: exit,
          latitude: location?.latitude,
          longitude: location?.longitude,
        )
        .bucket;
    return RhythmBlock(
      startFraction: start,
      widthFraction: width,
      isNight: bucket == TimeOfDayBucket.night,
    );
  }).toList();
}
