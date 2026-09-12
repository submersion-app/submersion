import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// TTS of the source dive at the end of its working portion, for the
/// plan-vs-actual strip; null when the plan has no source dive.
final sourceDiveTtsSecondsProvider = FutureProvider<int?>((ref) async {
  final dive = await ref.watch(sourceDiveForPlanProvider.future);
  if (dive == null || dive.profile.isEmpty) return null;
  final analysis = await ref.watch(profileAnalysisProvider(dive.id).future);
  return loggedTtsSeconds(profile: dive.profile, ttsCurve: analysis?.ttsCurve);
});
