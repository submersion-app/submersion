import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_times.dart';
import 'package:submersion/features/dive_log/domain/services/otu_window_split.dart';

/// Resolves a dive's profile analysis; null when it has no profile.
typedef ProfileAnalysisLookup =
    Future<ProfileAnalysis?> Function(String diveId);

/// How far before a window's start a dive can begin and still reach into it.
///
/// Callers widen their dive query by this much so a dive that started the
/// evening before a window opens (and crossed midnight into it) is found.
const otuWindowLookback = Duration(days: 1);

/// Total OTU that [dives] accrued inside `[from, to)`.
///
/// The one place daily and weekly OTU totals are summed: the dive detail's
/// weekly row (`weeklyOtuProvider`), the residual same-day OTU carried into a
/// dive (`_computeResidualOtu`) and the live readout (`cnsOtuSnapshotProvider`)
/// differ only in which dives they pass and where the window sits.
///
/// A dive crossing a window edge contributes only the part it accrued inside
/// the window (see [OtuWindowSplit]). A dive without an analysis contributes
/// nothing. Analyses are independent, so they are resolved together.
Future<double> sumOtuInWindow({
  required Iterable<DiveTimes> dives,
  required DateTime from,
  required DateTime to,
  required ProfileAnalysisLookup analysisOf,
}) async {
  final overlapping = dives.where((d) => _overlaps(d, from, to)).toList();
  final analyses = await Future.wait([
    for (final dive in overlapping) analysisOf(dive.id),
  ]);

  var total = 0.0;
  for (var i = 0; i < overlapping.length; i++) {
    final analysis = analyses[i];
    if (analysis == null) continue;
    final dive = overlapping[i];
    total += OtuWindowSplit.otuWithin(
      totalOtu: analysis.o2Exposure.otu,
      otuCurve: analysis.otuCurve,
      curveTimestamps: _curveTimestamps(analysis),
      diveStart: dive.entryTime ?? dive.dateTime,
      diveEnd: dive.effectiveExitTime,
      from: from,
      to: to,
    );
  }
  return total;
}

bool _overlaps(DiveTimes dive, DateTime from, DateTime to) {
  final start = dive.entryTime ?? dive.dateTime;
  if (!start.isBefore(to)) return false;
  return dive.effectiveExitTime.isAfter(from) || !start.isBefore(from);
}

/// Seconds-from-start of each [ProfileAnalysis.otuCurve] sample.
///
/// The analysis keeps no timestamp list of its own; its ascent-rate series is
/// computed from the same samples as the OTU curve, one point per sample, so
/// it carries them. Null when the two do not line up, which makes the split
/// fall back to elapsed time.
List<int>? _curveTimestamps(ProfileAnalysis analysis) {
  final curve = analysis.otuCurve;
  final rates = analysis.ascentRates;
  if (curve == null || rates.length != curve.length) return null;
  return [for (final point in rates) point.timestamp];
}
