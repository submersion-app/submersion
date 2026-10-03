import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
