import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final safetyFindingsRepositoryProvider = Provider<SafetyFindingsRepository>((
  ref,
) {
  return SafetyFindingsRepository();
});

/// Compute-through-cache: returns the stored review when it is current,
/// otherwise runs the engine over the profile analysis and persists the
/// result. Returns null when the dive has never been analyzed and has no
/// usable profile.
final safetyReviewProvider = FutureProvider.family<SafetyReview?, String>((
  ref,
  diveId,
) async {
  final repo = ref.watch(safetyFindingsRepositoryProvider);

  // getReview is a one-shot SELECT, not a Drift stream, so this provider only
  // re-runs when invalidated. A sync imports safety review/finding rows (and a
  // batch "Analyze all dives" writes them) directly to the DB, bypassing every
  // local notifier. Self-invalidate on the dive detail-change stream -- which
  // now includes both safety tables -- so a freshly synced or batch-analyzed
  // review appears without an app restart. Mirrors analysisDiveProvider.
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );

  final stored = await repo.getReview(diveId);
  if (stored != null &&
      stored.engineVersion >= SafetyReviewService.engineVersion) {
    return stored;
  }

  // Master toggle off: surface whatever is stored but never compute.
  if (!ref.watch(safetyReviewEnabledProvider)) return stored;

  final analysis = await ref.watch(profileAnalysisProvider(diveId).future);
  if (analysis == null || analysis.ascentRates.isEmpty) return stored;

  final now = DateTime.now();
  final review = SafetyReview(
    diveId: diveId,
    engineVersion: SafetyReviewService.engineVersion,
    reviewedAt: now,
    findings: const SafetyReviewService().review(
      diveId: diveId,
      analysis: analysis,
      now: now,
    ),
  );
  await repo.saveReview(review);
  return review;
});
