import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
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
///
/// Current means the same engine version AND the same inputs: the stored
/// fingerprint must match the active diver's own settings
/// ([diverAnalysisSettingsProvider]). A review this build cannot judge, from
/// a newer engine or under a newer fingerprint format, came from a newer
/// peer and is kept ([_isCurrent]). A review computed on another diver's
/// settings (#2564), on settings edited since, or before inputs were recorded
/// is recomputed on next view (#2592). saveReview keeps a recomputed
/// finding's id and dismissal, so a dismissal survives the recompute.
///
/// A review is saved only from an analysis that ran on exactly those
/// settings. While a metric source is switched on the chart the analysis is
/// a view of the dive, not the diver's review, so the stored one is shown.
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

  // Compare against the active diver's settings, not the placeholder or the
  // previous diver's still in state during a switch.
  final settingsLoaded = await awaitCurrentDiverSettings(ref);
  final currentInputs = ref.watch(diverAnalysisSettingsProvider).fingerprint;

  final stored = await repo.getReview(diveId);
  if (stored != null && _isCurrent(stored, currentInputs)) return stored;

  // The toggle below is per diver: right after a diver switch it still reads
  // the previous diver's until the new diver's settings load (#2564).
  await awaitCurrentDiverSettings(ref);

  // Master toggle off: surface whatever is stored but never compute.
  if (!ref.watch(safetyReviewEnabledProvider)) return stored;
  // The diver's settings failed to load, so state is not theirs: computing
  // would persist a review built on the placeholder or another diver's.
  if (!settingsLoaded) return stored;

  final analysis = await ref.watch(profileAnalysisProvider(diveId).future);
  if (analysis == null || analysis.ascentRates.isEmpty) return stored;
  // Ran on other inputs: a chart source toggle, settings that have moved
  // since this analysis was computed (it rebuilds, and this with it), or an
  // analysis that records none, which cannot show it used the diver's.
  if (analysis.inputsFingerprint != currentInputs) return stored;

  final now = DateTime.now();
  // Return what was stored, not the engine's raw output: a kept finding
  // keeps its stored id and dismissal, and a dismiss must address that id.
  return repo.saveReview(
    SafetyReview(
      diveId: diveId,
      engineVersion: SafetyReviewService.engineVersion,
      reviewedAt: now,
      inputsHash: currentInputs,
      findings: const SafetyReviewService().review(
        diveId: diveId,
        analysis: analysis,
        now: now,
      ),
    ),
  );
});

/// Whether [stored] may be served as is under [currentInputs].
///
/// A review from a newer engine is kept whatever its fingerprint: this build
/// would recompute it with an older engine and overwrite the newer peer's.
/// At this engine version the fingerprint must match, unless it was written
/// in a newer format this build cannot compare, which is kept for the same
/// reason. An older engine, or no fingerprint at all, is recomputed.
bool _isCurrent(SafetyReview stored, String currentInputs) {
  const engine = SafetyReviewService.engineVersion;
  if (stored.engineVersion > engine) return true;
  if (stored.engineVersion < engine) return false;
  final hash = stored.inputsHash;
  if (hash == null) return false;
  return hash == currentInputs || AnalysisSettings.isNewerFormat(hash);
}

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
