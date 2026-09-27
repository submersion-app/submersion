import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';

/// The bottom time one data source's own profile yields, in seconds.
///
/// A source row stores what its computer measured, the runtime; bottom time
/// is derived from a profile with a depth threshold and is never stored in
/// its place (issue #2421). Anything that rebuilds a dive's bottom time from
/// a single source (split, a primary swap) derives it here instead.
///
/// The source's series are the ones it owns by [sourceId]; a series that
/// predates the owning-source column and carries no owner counts when it
/// shares the source's [computerId]. A series another source owns never
/// counts. Among several, the primary series wins. The result never exceeds
/// [runtimeSeconds]; null when there is no series or it is too sparse.
int? sourceBottomTimeSeconds(
  Iterable<ProfileSeries> series, {
  required String sourceId,
  required String? computerId,
  required int? runtimeSeconds,
}) {
  final owned = [
    for (final s in series)
      if (s.sourceId == sourceId ||
          (s.sourceId == null &&
              computerId != null &&
              s.computerId == computerId))
        s,
  ];
  if (owned.isEmpty) return null;
  final chosen = owned.firstWhere(
    (s) => s.isPrimary,
    orElse: () => owned.first,
  );
  return BottomTimeCalculator.secondsFromSamples([
    for (final sample in chosen.samples)
      (timestamp: sample.timestamp, depth: sample.depth),
  ], totalDurationSeconds: runtimeSeconds);
}
