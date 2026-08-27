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

/// The safety finding currently selected for profile-chart highlighting, or
/// null when none. Session state keyed by dive ID: the safety review section
/// writes it on tile tap; the detail and fullscreen profile charts read it.
/// Stores the whole finding (timestamps, severity) so chart consumers never
/// depend on the async [safetyReviewProvider]. Not persisted.
final selectedSafetyFindingProvider =
    StateProvider.family<SafetyFinding?, String>((ref, diveId) => null);

/// Dismisses or restores a finding and keeps UI state consistent: a dismissed
/// finding can no longer be the chart selection. Persists through
/// [SafetyFindingsRepository.setDismissed], which also bumps the parent
/// dive's HLC so the change syncs (findings tables have no HLC of their own).
Future<void> setSafetyFindingDismissed(
  WidgetRef ref, {
  required SafetyFinding finding,
  required bool dismissed,
}) async {
  final diveId = finding.diveId;
  if (dismissed) {
    final selected = ref.read(selectedSafetyFindingProvider(diveId).notifier);
    if (selected.state?.id == finding.id) {
      selected.state = null;
    }
  }
  await ref
      .read(safetyFindingsRepositoryProvider)
      .setDismissed(
        findingId: finding.id,
        dismissed: dismissed,
        now: DateTime.now(),
      );
  ref.invalidate(safetyReviewProvider(diveId));
}

/// The safety rule ids the diver currently has switched on, as stored
/// dbValues.
///
/// Bulk dismiss/restore is scoped to this set so a rule hidden in settings is
/// never acted on behind the user's back, and so a finding written by a newer
/// build (an unrecognised rule_id, which [SafetyFindingsRepository.getReview]
/// already drops) is never dismissed sight unseen.
Set<String> enabledSafetyRuleIds(AppSettings settings) => {
  for (final rule in SafetyRuleId.values)
    if (!settings.safetyReviewDisabledRules.contains(rule.dbValue))
      rule.dbValue,
};

/// Dismisses or restores every finding on [diveId] whose rule is enabled,
/// returning how many changed.
///
/// The bulk sibling of [setSafetyFindingDismissed], with the same UI
/// housekeeping: a dismissed finding can no longer be the chart selection.
Future<int> setAllSafetyFindingsDismissed(
  WidgetRef ref, {
  required String diveId,
  required bool dismissed,
}) async {
  final changed = await ref
      .read(safetyFindingsRepositoryProvider)
      .setDismissedForDives(
        diveIds: [diveId],
        dismissed: dismissed,
        enabledRuleIds: enabledSafetyRuleIds(ref.read(settingsProvider)),
        now: DateTime.now(),
      );
  // Clear the selection only once the write lands. Clearing first would drop
  // the user's chart highlight as the sole visible effect of a failed write.
  if (dismissed) {
    ref.read(selectedSafetyFindingProvider(diveId).notifier).state = null;
  }
  ref.invalidate(safetyReviewProvider(diveId));
  return changed;
}
