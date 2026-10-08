import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// The samples [profileAnalysisProvider]'s curves are indexed like. On a dive
/// with several computers that is the primary's own series, not
/// `dive.profile`, which interleaves every computer's samples.
Future<List<DiveProfilePoint>> _analysedSamples(Ref ref, Dive dive) async {
  final series = await ref.watch(diveAnalysisSeriesProvider(dive.id).future);
  return series?.points ?? dive.profile;
}

/// TTS of the source dive at the end of its working portion, for the
/// plan-vs-actual strip; null when the plan has no source dive.
final sourceDiveTtsSecondsProvider = FutureProvider<int?>((ref) async {
  final dive = await ref.watch(sourceDiveForPlanProvider.future);
  if (dive == null || dive.profile.isEmpty) return null;
  final analysis = await ref.watch(profileAnalysisProvider(dive.id).future);
  return loggedTtsSeconds(
    profile: await _analysedSamples(ref, dive),
    ttsCurve: analysis?.ttsCurve,
  );
});

/// The source dive's last computer CNS reading, for the plan-vs-actual strip;
/// null when the plan has no source dive or the computer logged no CNS
/// series.
///
/// The last reading rather than the last sample's, since many computers log
/// CNS only every few samples, and of the analysed samples rather than
/// `dive.profile`, whose last reading may be another computer's (#2545).
/// Unlike [_analysedSamples] there is no `dive.profile` fallback: the series
/// is null only for an interleaved dive with no one recording to analyse,
/// where that fallback is exactly the mix of computers to avoid.
final sourceDiveCnsEndProvider = FutureProvider<double?>((ref) async {
  final dive = await ref.watch(sourceDiveForPlanProvider.future);
  if (dive == null || dive.profile.isEmpty) return null;
  final series = await ref.watch(diveAnalysisSeriesProvider(dive.id).future);
  if (series == null) return null;
  return extractComputerCns(series.points)?.cnsEnd;
});

/// Seconds the source dive spent holding deco stops, for the plan-vs-actual
/// strip; null when the plan has no source dive or the profile could not be
/// analysed.
final sourceDiveDecoSecondsProvider = FutureProvider<int?>((ref) async {
  final dive = await ref.watch(sourceDiveForPlanProvider.future);
  if (dive == null || dive.profile.isEmpty) return null;
  final analysis = await ref.watch(profileAnalysisProvider(dive.id).future);
  if (analysis == null) return null;
  return loggedDecoSeconds(
    profile: await _analysedSamples(ref, dive),
    decoStopCurve: analysis.decoStopCurve,
  );
});
