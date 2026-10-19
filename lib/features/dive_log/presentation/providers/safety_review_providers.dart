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
///
/// The review grades the dive-level analysis ([profileAnalysisProvider]),
/// which on a dive the chart draws one source at a time replays the primary
/// source's own samples rather than every computer's interleaved
/// ([diveAnalysisSeriesProvider]).
final safetyReviewProvider = FutureProvider.family<SafetyReview?, String>((
  ref,
  diveId,
) async {
  // getReview is a one-shot SELECT, not a Drift stream, so this provider only
  // re-runs when invalidated. A sync imports safety review/finding rows (and a
  // batch "Analyze all dives" writes them) directly to the DB, bypassing every
  // local notifier. Self-invalidate on the dive detail-change stream -- which
  // now includes both safety tables -- so a freshly synced or batch-analyzed
  // review appears without an app restart. Mirrors analysisDiveProvider.
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return _reviewDive(ref, diveId, recompute: false);
});

/// [safetyReviewProvider] without the "stored review is current" shortcut:
/// runs the engine again even when the stored review matches this engine and
/// these settings. "Analyze all dives" reads this, because a user reaches for
/// it after correcting a dive's data, which neither the engine version nor
/// the settings fingerprint can see (#1643).
///
/// Every other guard still holds: a review this build cannot judge (a newer
/// engine or fingerprint format) is kept, and when the engine cannot run
/// (toggle off, settings not loaded, no usable analysis) the stored review is
/// returned untouched rather than lost. AutoDispose, and read once per dive
/// through a short-lived listener, so every read computes afresh and a long
/// sweep leaves nothing behind; it does not watch for changes.
final safetyReviewRecomputeProvider = FutureProvider.autoDispose
    .family<SafetyReview?, String>(
      (ref, diveId) => _reviewDive(ref, diveId, recompute: true),
    );

Future<SafetyReview?> _reviewDive(
  Ref ref,
  String diveId, {
  required bool recompute,
}) async {
  // Set the moment this build is invalidated or rebuilt: Riverpod runs
  // onDispose callbacks then, whereas ref.mounted turns false only once the
  // replacement build starts, which for an unlistened provider is its next
  // read.
  var superseded = false;
  ref.onDispose(() => superseded = true);

  final repo = ref.watch(safetyFindingsRepositoryProvider);

  // Compare against the active diver's settings, not the placeholder or the
  // previous diver's still in state during a switch.
  final settingsLoaded = await awaitCurrentDiverSettings(ref);
  final currentInputs = ref.watch(diverAnalysisSettingsProvider).fingerprint;

  final stored = await repo.getReview(diveId);
  if (stored != null &&
      (recompute
          ? _isFromNewerBuild(stored)
          : _isCurrent(stored, currentInputs))) {
    return stored;
  }

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
  // Invalidated while awaiting above: a newer build owns this dive's review,
  // so a save here could land after it and overwrite its result (or the
  // Analyze all dives recompute) with this older one. Invalidation does not
  // cancel the awaits, so this build has to stand down itself.
  if (superseded) return stored;

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
}

/// Whether [stored] may be served as is under [currentInputs].
///
/// A review from a newer engine is kept whatever its fingerprint: this build
/// would recompute it with an older engine and overwrite the newer peer's.
/// At this engine version the fingerprint must match, unless it was written
/// in a newer format this build cannot compare, which is kept for the same
/// reason. An older engine, or no fingerprint at all, is recomputed.
bool _isCurrent(SafetyReview stored, String currentInputs) =>
    _isFromNewerBuild(stored) ||
    (stored.engineVersion == SafetyReviewService.engineVersion &&
        stored.inputsHash == currentInputs);

/// Whether [stored] came from a build newer than this one: a newer engine, or
/// this engine under a fingerprint format this build cannot compare. Never
/// recomputed here, even on request, or this build would overwrite the newer
/// peer's review with its own older one.
bool _isFromNewerBuild(SafetyReview stored) {
  const engine = SafetyReviewService.engineVersion;
  if (stored.engineVersion != engine) return stored.engineVersion > engine;
  final hash = stored.inputsHash;
  return hash != null && AnalysisSettings.isNewerFormat(hash);
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
