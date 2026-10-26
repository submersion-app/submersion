import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/rules/data/services/import_rules_pass.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

// ============================================================================
// Public value types
// ============================================================================

/// A (type, index) pair identifying a pending-review row.
class PendingLocation {
  const PendingLocation({required this.type, required this.index});
  final ImportEntityType type;
  final int index;
}

/// Fields the dive review list's non-duplicate rows can be sorted by.
enum DiveReviewSortField { date, depth, duration }

/// Match score threshold at or above which a cross-computer duplicate is
/// auto-suggested for consolidation instead of being left for the user to
/// decide.
///
/// Deliberately higher than the 0.7 "probable duplicate" threshold used
/// elsewhere -- auto-selecting an action (rather than merely flagging a row
/// for review) should only happen when the match is very likely correct.
const double kAutoConsolidateScore = 0.85;

// ============================================================================
// State
// ============================================================================

/// Immutable state for the unified import wizard.
class ImportWizardState {
  const ImportWizardState({
    this.currentStep = 0,
    this.bundle,
    this.selections = const {},
    this.duplicateActions = const {},
    this.pendingDuplicateReview = const {},
    this.retainSourceDiveNumbers = false,
    this.duplicateCheckFailed = false,
    this.isRetargeting = false,
    this.diveSortField = DiveReviewSortField.date,
    this.diveSortAscending = false,
    this.importTags = const [],
    this.autoTagThisImport = false,
    this.importPhase,
    this.importCurrent = 0,
    this.importTotal = 0,
    this.importResult,
    this.isImporting = false,
    this.isCancellationRequested = false,
    this.error,
    this.importRefused = false,
    this.ruleRuns = const [],
    this.rulesFailed = false,
    this.ruleSkippedRules = const [],
    this.ruleSkippedActions = const [],
  });

  /// The current wizard step index.
  final int currentStep;

  /// The bundle produced by the adapter after acquisition.
  final ImportBundle? bundle;

  /// Selected item indices per entity type.
  final Map<ImportEntityType, Set<int>> selections;

  /// User-chosen action per duplicate item, keyed by entity type and index.
  final Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions;

  /// Per-entity-type set of indices whose duplicate status is flagged but
  /// whose resolution has not yet been explicitly chosen by the user.
  ///
  /// An index is present in this set when the row was flagged as a suspected
  /// duplicate and the user has not yet explicitly acted on it. Per-row and
  /// per-tab bulk actions remove indices from the relevant set. The Import
  /// button is gated on this set being empty across all types.
  final Map<ImportEntityType, Set<int>> pendingDuplicateReview;

  /// When true, imported dives keep their original dive numbers from the
  /// source file instead of being auto-assigned sequential numbers.
  final bool retainSourceDiveNumbers;

  /// Which field the dive tab's non-duplicate rows are sorted by.
  final DiveReviewSortField diveSortField;

  /// Sort direction for [diveSortField]. Defaults to descending so the
  /// newest dive (or deepest/longest, depending on field) appears first.
  final bool diveSortAscending;

  /// Tags to apply to all imported dives.
  final List<TagSelection> importTags;

  /// Whether auto-tagging applies to this import (issue #998): the review
  /// step's Import Options switch. Seeded from the diver's saved
  /// preference, then owned by the diver for the rest of the session.
  ///
  /// Tracked explicitly rather than inferred from [importTags] by name, so a
  /// tag the diver typed or picked by hand that happens to share the default
  /// name neither reads as auto-tagged nor gets removed by the switch.
  final bool autoTagThisImport;

  /// The current import phase (e.g. dives, sites, applyingTags).
  final ImportPhase? importPhase;

  /// Number of items processed in the current import phase.
  final int importCurrent;

  /// Total items in the current import phase.
  final int importTotal;

  /// Result populated after a successful import.
  final UnifiedImportResult? importResult;

  /// True while the adapter's [performImport] is running.
  final bool isImporting;

  /// True once the user has requested cancellation of the running import.
  /// The adapter is notified via its cancellation token and returns a partial
  /// result; this flag lets the UI render a "Cancelling..." state until that
  /// return happens.
  final bool isCancellationRequested;

  /// Non-null when an error has occurred.
  final String? error;

  /// The import was refused because another one still runs; the summary
  /// says so in the diver's language.
  final bool importRefused;

  /// What the diver's logbook rules changed after the import (#3513).
  final List<RuleRunResult> ruleRuns;

  /// The rules could not run after the import; the import stands.
  final bool rulesFailed;

  /// Duplicate detection failed for the current bundle, which is shown
  /// without it. The review step says so.
  final bool duplicateCheckFailed;

  /// The import is being sent to another profile and its bundle re-checked
  /// (issue #2050). The rows still carry the previous profile's choices
  /// until it lands, so importing is held off.
  final bool isRetargeting;

  /// Rules the import skipped, and rules with an action naming a deleted
  /// item, for the summary to report.
  final List<String> ruleSkippedRules;
  final List<String> ruleSkippedActions;

  ImportWizardState copyWith({
    int? currentStep,
    ImportBundle? bundle,
    bool clearBundle = false,
    Map<ImportEntityType, Set<int>>? selections,
    Map<ImportEntityType, Map<int, DuplicateAction>>? duplicateActions,
    Map<ImportEntityType, Set<int>>? pendingDuplicateReview,
    bool? retainSourceDiveNumbers,
    bool? duplicateCheckFailed,
    bool? isRetargeting,
    DiveReviewSortField? diveSortField,
    bool? diveSortAscending,
    List<TagSelection>? importTags,
    bool? autoTagThisImport,
    ImportPhase? importPhase,
    bool clearImportPhase = false,
    int? importCurrent,
    int? importTotal,
    UnifiedImportResult? importResult,
    bool clearImportResult = false,
    bool? isImporting,
    bool? isCancellationRequested,
    String? error,
    bool clearError = false,
    bool? importRefused,
    List<RuleRunResult>? ruleRuns,
    bool? rulesFailed,
    List<String>? ruleSkippedRules,
    List<String>? ruleSkippedActions,
  }) {
    return ImportWizardState(
      currentStep: currentStep ?? this.currentStep,
      bundle: clearBundle ? null : (bundle ?? this.bundle),
      selections: selections ?? this.selections,
      duplicateActions: duplicateActions ?? this.duplicateActions,
      pendingDuplicateReview:
          pendingDuplicateReview ?? this.pendingDuplicateReview,
      retainSourceDiveNumbers:
          retainSourceDiveNumbers ?? this.retainSourceDiveNumbers,
      duplicateCheckFailed: duplicateCheckFailed ?? this.duplicateCheckFailed,
      isRetargeting: isRetargeting ?? this.isRetargeting,
      diveSortField: diveSortField ?? this.diveSortField,
      diveSortAscending: diveSortAscending ?? this.diveSortAscending,
      importTags: importTags ?? this.importTags,
      autoTagThisImport: autoTagThisImport ?? this.autoTagThisImport,
      importPhase: clearImportPhase ? null : (importPhase ?? this.importPhase),
      importCurrent: importCurrent ?? this.importCurrent,
      importTotal: importTotal ?? this.importTotal,
      importResult: clearImportResult
          ? null
          : (importResult ?? this.importResult),
      isImporting: isImporting ?? this.isImporting,
      isCancellationRequested:
          isCancellationRequested ?? this.isCancellationRequested,
      error: clearError ? null : (error ?? this.error),
      importRefused: importRefused ?? this.importRefused,
      ruleRuns: ruleRuns ?? this.ruleRuns,
      rulesFailed: rulesFailed ?? this.rulesFailed,
      ruleSkippedRules: ruleSkippedRules ?? this.ruleSkippedRules,
      ruleSkippedActions: ruleSkippedActions ?? this.ruleSkippedActions,
    );
  }

  /// Pending-review indices for a given entity type. Empty if none.
  Set<int> pendingFor(ImportEntityType type) {
    return pendingDuplicateReview[type] ?? const {};
  }

  /// Whether any entity type has at least one pending-review row.
  bool get hasPendingReviews =>
      pendingDuplicateReview.values.any((set) => set.isNotEmpty);

  /// Total count of pending-review rows across all entity types.
  int get totalPending =>
      pendingDuplicateReview.values.fold(0, (sum, s) => sum + s.length);
}

// ============================================================================
// Notifier
// ============================================================================

/// Manages the post-acquisition state of the unified import wizard.
///
/// Orchestrates review selections, duplicate actions, import progress,
/// and results. Source-specific logic is delegated to an [ImportSourceAdapter].
/// The unfilled planned dives a download may fill (issue #2002), keyed by
/// the import's target profile (null = unscoped). Follows the dives tick so
/// a plan created or promoted mid-wizard shows up.
final plannedFillCandidatesProvider = FutureProvider.autoDispose
    .family<List<Dive>, String?>((ref, diverId) {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      return repository.getPlannedDives(diverId: diverId);
    });

class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  ImportWizardNotifier(
    this._adapter, {
    TagRepository? tagRepository,
    String? diverId,
    RuleEngine? ruleEngine,
    ImportJobNotifier? job,
    bool continuesWithoutWizard = false,
  }) : _tagRepository = tagRepository,
       _diverId = diverId,
       _ruleEngine = ruleEngine,
       _job = job,
       _continuesWithoutWizard = continuesWithoutWizard,
       super(const ImportWizardState());

  static final _log = LoggerService.forClass(ImportWizardNotifier);

  final ImportSourceAdapter _adapter;
  final TagRepository? _tagRepository;
  final RuleEngine? _ruleEngine;
  String? _diverId;

  /// The app-wide job an import runs as (see [importJobProvider]): it owns
  /// the cancellation token and outlives this notifier. Null in tests that
  /// do not need one; the import then runs on a token of its own.
  final ImportJobNotifier? _job;

  /// Whether the adapter keeps working once the wizard closes, so an import
  /// may go on without it. One that does not is cancelled when the wizard
  /// goes away, as leaving always did.
  final bool _continuesWithoutWizard;

  /// The running import's cancellation token, or null when no import is in
  /// progress. It comes from the job when there is one, so this notifier and
  /// the job cancel through the same token.
  ImportCancellationToken? _cancelToken;

  /// Set the validated diver ID for tag association during import.
  void setDiverId(String? diverId) {
    _diverId = diverId;
  }

  /// Send this import to another profile from the review step (issue #2050).
  ///
  /// Duplicate matches and planned-dive fills depend on whose dives the
  /// download is compared with, so the bundle is rebuilt and re-checked for
  /// [diverId] and its per-row choices start over. Until that lands,
  /// [ImportWizardState.isRetargeting] holds importing off, and only the
  /// latest of overlapping changes is applied. A failed check falls back to
  /// the unchecked bundle and says so, as entering the review step does.
  /// Import tags are kept. Does nothing unless the adapter can be retargeted
  /// and the bundle offers a choice.
  Future<void> changeTargetDiver(String diverId) async {
    final adapter = _adapter;
    if (adapter is! RetargetableImportAdapter) return;
    if (state.bundle?.targetChoice == null) return;
    final previous = state.bundle!.targetChoice!.chosenDiverId;
    final retargetable = adapter as RetargetableImportAdapter;
    final generation = ++_retargetGeneration;
    state = state.copyWith(isRetargeting: true);
    try {
      await retargetable.setTargetDiver(diverId);
      final ImportBundle bundle;
      try {
        bundle = await adapter.buildBundle();
      } catch (e, stackTrace) {
        // The review list still shows the previous profile's bundle, so the
        // adapter goes back to it rather than writing elsewhere.
        _log.error(
          'Could not rebuild the import for profile $diverId; keeping '
          '$previous',
          error: e,
          stackTrace: stackTrace,
        );
        if (generation == _retargetGeneration) {
          await retargetable.setTargetDiver(previous);
        }
        return;
      }
      var checkFailed = false;
      ImportBundle checked;
      try {
        checked = await adapter.checkDuplicates(bundle);
      } catch (e, stackTrace) {
        _log.error(
          'Duplicate detection failed after changing profile; continuing '
          'without it',
          error: e,
          stackTrace: stackTrace,
        );
        checked = bundle;
        checkFailed = true;
      }
      if (!mounted || generation != _retargetGeneration) return;
      setBundle(checked, duplicateCheckFailed: checkFailed);
    } finally {
      if (mounted && generation == _retargetGeneration) {
        state = state.copyWith(isRetargeting: false);
      }
    }
  }

  /// Counts [changeTargetDiver] calls, so a slower earlier one cannot land
  /// over a later one.
  int _retargetGeneration = 0;

  /// Request cancellation of the running import. Cooperative — the adapter
  /// finishes the current work item (e.g. the current dive's transaction)
  /// before exiting the loop with a partial result.
  ///
  /// Safe to call when no import is in progress: it just no-ops.
  /// Safe to call repeatedly: the token's own `cancel()` is idempotent.
  void cancelImport() {
    final token = _cancelToken;
    if (token == null || token.isCancelled) return;
    final job = _job;
    if (job != null) {
      job.cancel();
    } else {
      token.cancel();
    }
    state = state.copyWith(isCancellationRequested: true);
  }

  @override
  void dispose() {
    final token = _cancelToken;
    if (token != null) {
      final job = _job;
      if (job != null) {
        // After the tree has settled: this runs while the wizard is being
        // unmounted, and the job's listeners may rebuild other widgets.
        scheduleMicrotask(() => job.detach(token));
      } else if (!_continuesWithoutWizard) {
        token.cancel();
      }
    }
    super.dispose();
  }

  /// The duplicate actions supported by the underlying adapter, across all
  /// entity types. Prefer [duplicateActionsFor] when a specific tab is in
  /// scope: some adapters implement an action for only some entity types.
  Set<DuplicateAction> get supportedDuplicateActions =>
      _adapter.supportedDuplicateActions;

  /// The duplicate actions the adapter supports for entities of [type].
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      _adapter.duplicateActionsFor(type);

  // -------------------------------------------------------------------------
  // setBundle
  // -------------------------------------------------------------------------

  /// Store [bundle] and initialize selections and pending-review state.
  ///
  /// For each entity group:
  /// - All items are selected except those in [EntityGroup.duplicateIndices].
  /// - Every suspected-duplicate index is recorded in
  ///   [ImportWizardState.pendingDuplicateReview] so the user must explicitly
  ///   choose an action before the row gets a recorded resolution -- UNLESS
  ///   it qualifies for the cross-computer auto-consolidate default below.
  /// - [ImportWizardState.duplicateActions] is left empty for every other
  ///   duplicate — no auto-defaults are written for plain probable or
  ///   possible matches (#200). The user drains the pending set via per-row
  ///   ([setDuplicateAction]) or bulk actions.
  ///
  /// Auto-consolidate default: a dive duplicate whose [DiveMatchResult.score]
  /// is at least [kAutoConsolidateScore] AND whose
  /// [DiveMatchResult.matchedComputerId] is known AND differs from the
  /// current download's computer is pre-selected with
  /// [DuplicateAction.consolidate] and removed from the pending-review set.
  /// A same-computer match (a plain re-download) is never auto-selected —
  /// it stays pending like any other duplicate.
  ///
  /// Exact-source-hit default: a dive duplicate whose
  /// [DiveMatchResult.matchedExistingSource] is true is ALWAYS pre-selected
  /// with [DuplicateAction.skip] and removed from the pending-review set,
  /// regardless of score or [DiveMatchResult.matchedComputerId]. This is a
  /// re-download of data already recorded on the matched dive (its
  /// fingerprint or source UUID is already one of the matched dive's
  /// `dive_data_sources` keys) — auto-consolidating it would fold the same
  /// data in a second time.
  ///
  /// [duplicateCheckFailed] records that [bundle] is shown without duplicate
  /// detection, which the review step reports.
  void setBundle(ImportBundle bundle, {bool duplicateCheckFailed = false}) {
    final selections = <ImportEntityType, Set<int>>{};
    final pendingReview = <ImportEntityType, Set<int>>{};
    final duplicateActions = <ImportEntityType, Map<int, DuplicateAction>>{};

    final currentComputerId = bundle.source.currentComputerId;

    for (final entry in bundle.groups.entries) {
      final type = entry.key;
      final group = entry.value;

      final allIndices = Set<int>.from(
        List.generate(group.items.length, (i) => i),
      );
      selections[type] = allIndices.difference(group.duplicateIndices);

      var pendingForType = Set<int>.from(group.duplicateIndices);

      if (type == ImportEntityType.dives) {
        final matchResults = group.matchResults;
        if (matchResults != null) {
          for (final index in group.duplicateIndices) {
            final match = matchResults[index];
            if (match == null) continue;

            if (match.matchedExistingSource || match.inBatchIndex != null) {
              // Re-download of data the matched dive already carries as a
              // source, OR a duplicate of another dive within this same
              // import batch: default to skip and never auto-consolidate,
              // no matter the score or matchedComputerId.
              duplicateActions.putIfAbsent(type, () => {})[index] =
                  DuplicateAction.skip;
              selections[type] = selections[type]!.difference({index});
              pendingForType = pendingForType.difference({index});
              continue;
            }

            // A same-day planned dive of the target profile (issue #2002):
            // default to filling it. The row stays selected and needs no
            // decision; the card offers Change and Import as new.
            if (match.isPlannedFill) {
              duplicateActions.putIfAbsent(type, () => {})[index] =
                  DuplicateAction.fillPlanned;
              selections[type] = {...selections[type]!, index};
              pendingForType = pendingForType.difference({index});
              continue;
            }

            final matchedComputerId = match.matchedComputerId;
            // Auto-consolidate only for dive-computer downloads
            // (currentComputerId non-null): a file-based import cannot
            // prove the match is cross-computer, so it stays pending.
            if (match.score >= kAutoConsolidateScore &&
                currentComputerId != null &&
                matchedComputerId != null &&
                matchedComputerId != currentComputerId) {
              duplicateActions.putIfAbsent(type, () => {})[index] =
                  DuplicateAction.consolidate;
              selections[type] = {...selections[type]!, index};
              pendingForType = pendingForType.difference({index});
            }
          }
        }

        // First-sync cutoff default (tier-1 filter): a downloaded dive at or
        // before the diver's cutoff is pre-selected to skip and never left
        // for review, using the exact same mechanism as the
        // matchedExistingSource default above. An index that is both
        // matched and auto-skipped is idempotent here -- setting the same
        // map entry and removing from the same sets twice has no additional
        // effect -- so it ends up skipped once, not double-handled.
        final autoSkipIndices = group.autoSkipIndices;
        if (autoSkipIndices != null) {
          for (final index in autoSkipIndices) {
            duplicateActions.putIfAbsent(type, () => {})[index] =
                DuplicateAction.skip;
            selections[type] = selections[type]!.difference({index});
            pendingForType = pendingForType.difference({index});
          }
        }
      }

      // A duplicate whose only possible action is Skip (a fill already here,
      // cylinder passports phase 5) has nothing to decide: it is skipped by
      // default and never holds the Import button.
      final choices = _adapter.duplicateActionsFor(type);
      if (setEquals(choices, const {DuplicateAction.skip})) {
        for (final index in pendingForType) {
          duplicateActions.putIfAbsent(type, () => {})[index] =
              DuplicateAction.skip;
        }
        pendingForType = const {};
      }

      if (pendingForType.isNotEmpty) {
        pendingReview[type] = pendingForType;
      }
    }

    state = state.copyWith(
      bundle: bundle,
      duplicateCheckFailed: duplicateCheckFailed,
      selections: selections,
      duplicateActions: duplicateActions,
      pendingDuplicateReview: pendingReview,
      currentStep: 1,
      clearError: true,
    );
  }

  // -------------------------------------------------------------------------
  // Selection management
  // -------------------------------------------------------------------------

  /// Toggle the selection of a single item.
  ///
  /// When [index] is being turned on and it is NOT a genuine duplicate (i.e.
  /// it is absent from [EntityGroup.duplicateIndices]), this also clears any
  /// [DuplicateAction.skip] seeded for it by [setBundle]'s first-sync-cutoff
  /// auto-skip default. Without this, re-selecting a rescued row from the
  /// collapsed "older dives" section would leave the stale skip action in
  /// place, and [ImportSourceAdapter.performImport] would silently drop the
  /// dive even though the UI shows it as selected for import. Genuine
  /// duplicate rows never reach this path with a meaningful action — their
  /// action is set via [setDuplicateAction] from `DuplicateActionCard` — so
  /// this can't clobber a user's duplicate-resolution choice.
  ///
  /// A shift-click range can span a duplicate row in the middle without the
  /// user intending to select it, so -- exactly like [selectAll] -- indices
  /// in [EntityGroup.duplicateIndices] are never added by this method. They
  /// stay eligible for [setSelections]'s removal path, though that's moot in
  /// practice since they can never have been added in the first place.
  void setSelections(ImportEntityType type, Set<int> indices, bool select) {
    final current = state.selections[type] ?? const <int>{};
    final updated = Set<int>.from(current);

    if (select) {
      final group = state.bundle?.groups[type];
      final selectable = group == null
          ? indices
          : indices.difference(group.duplicateIndices);
      updated.addAll(selectable);
    } else {
      updated.removeAll(indices);
    }

    final updatedPending = _drainPending(type, indices);
    final updatedActions = _clearSeededSkip(type, indices, select);

    state = state.copyWith(
      selections: {...state.selections, type: updated},
      duplicateActions: updatedActions,
      pendingDuplicateReview: updatedPending,
    );
  }

  void toggleSelection(ImportEntityType type, int index) {
    final current = state.selections[type] ?? const <int>{};
    final updated = Set<int>.from(current);
    final isSelecting = !updated.contains(index);
    if (isSelecting) {
      updated.add(index);
    } else {
      updated.remove(index);
    }

    final updatedPending = _drainPending(type, {index});
    final updatedActions = _clearSeededSkip(type, {index}, isSelecting);

    state = state.copyWith(
      selections: {...state.selections, type: updated},
      duplicateActions: updatedActions,
      pendingDuplicateReview: updatedPending,
    );
  }

  /// Select all non-duplicate items for [type].
  ///
  /// Also clears any [DuplicateAction.skip] seeded by the first-sync-cutoff
  /// auto-skip default (see [toggleSelection]) for every newly-selected
  /// index, so a bulk "Select All" rescues auto-skipped rows the same way a
  /// single tap does.
  void selectAll(ImportEntityType type) {
    final group = state.bundle?.groups[type];
    if (group == null) return;

    final allIndices = Set<int>.from(
      List.generate(group.items.length, (i) => i),
    );
    final nonDuplicates = allIndices.difference(group.duplicateIndices);
    final updatedActions = _clearSeededSkip(type, nonDuplicates, true);

    state = state.copyWith(
      selections: {...state.selections, type: nonDuplicates},
      duplicateActions: updatedActions,
    );
  }

  /// Removes a seeded [DuplicateAction.skip] for any of [indices] that are
  /// NOT genuine duplicates, when [isSelecting] is true.
  ///
  /// Used by [toggleSelection] and [selectAll] to undo the first-sync-cutoff
  /// auto-skip default (see [setBundle]) the moment the user re-selects one
  /// of those rows. Indices in `group.duplicateIndices` are always left
  /// alone -- their action is owned by [setDuplicateAction] via
  /// `DuplicateActionCard`, never by this selection path.
  Map<ImportEntityType, Map<int, DuplicateAction>> _clearSeededSkip(
    ImportEntityType type,
    Set<int> indices,
    bool isSelecting,
  ) {
    if (!isSelecting) return state.duplicateActions;

    final group = state.bundle?.groups[type];
    if (group == null) return state.duplicateActions;

    final actionsForType = state.duplicateActions[type];
    if (actionsForType == null || actionsForType.isEmpty) {
      return state.duplicateActions;
    }

    final toClear = indices.where(
      (i) =>
          !group.duplicateIndices.contains(i) &&
          actionsForType[i] == DuplicateAction.skip,
    );
    if (toClear.isEmpty) return state.duplicateActions;

    final updated = Map<int, DuplicateAction>.from(actionsForType);
    for (final i in toClear) {
      updated.remove(i);
    }
    return {...state.duplicateActions, type: updated};
  }

  /// Deselect all items for [type].
  void deselectAll(ImportEntityType type) {
    state = state.copyWith(
      selections: {...state.selections, type: const <int>{}},
    );
  }

  // -------------------------------------------------------------------------
  // Retain source dive numbers
  // -------------------------------------------------------------------------

  /// Toggle whether imported dives retain their original dive numbers from
  /// the source file.
  void setRetainSourceDiveNumbers(bool value) {
    state = state.copyWith(retainSourceDiveNumbers: value);
  }

  /// Change the dive review list's sort field.
  ///
  /// Tapping the field that is already active flips the sort direction
  /// (ascending/descending); picking a different field switches to it with
  /// the default descending direction (newest/deepest/longest first).
  void setDiveSortField(DiveReviewSortField field) {
    if (state.diveSortField == field) {
      state = state.copyWith(diveSortAscending: !state.diveSortAscending);
    } else {
      state = state.copyWith(diveSortField: field, diveSortAscending: false);
    }
  }

  // -------------------------------------------------------------------------
  // Import tags
  // -------------------------------------------------------------------------

  /// Seed this bundle's default tag, following the diver's saved
  /// [autoTagImports] preference (issue #998): repeated imports otherwise
  /// pile up one dated tag per session, for every source alike (dive
  /// computer, file-based, cloud).
  ///
  /// Runs once per bundle, after [setBundle]. The first call seeds
  /// [ImportWizardState.autoTagThisImport] from [autoTagImports]. A later
  /// call -- Back from review, then Next again -- keeps whatever the diver
  /// chose for this import instead, via the Import Options switch or the
  /// chip's delete button, and swaps the previous bundle's chip for this
  /// bundle's: the name comes from the selected file or device and the date,
  /// either of which may have changed in between.
  ///
  /// [autoTagImports] is passed in by the caller rather than captured at
  /// construction: this method runs well after acquisition, so reading the
  /// setting here -- instead of baking in whatever `read` returned when the
  /// wizard's `ProviderScope` was first built -- avoids picking up a stale
  /// or default value for a diver switched to mid-session.
  void initializeDefaultTag({required bool autoTagImports}) {
    if (!_defaultTagSeeded) {
      _defaultTagSeeded = true;
      setAutoTagForThisImport(autoTagImports);
      return;
    }

    final freshName = _adapter.defaultTagName;
    if (_sameTagName(freshName, defaultTagName)) return;
    final enabled = state.autoTagThisImport;
    setAutoTagForThisImport(false);
    _defaultTagName = freshName;
    setAutoTagForThisImport(enabled);
  }

  /// Whether [initializeDefaultTag] has seeded this session yet; after that,
  /// the diver's per-import choice wins over the saved preference.
  bool _defaultTagSeeded = false;

  /// Whether the default chip in [ImportWizardState.importTags] was added by
  /// auto-tagging, as opposed to a same-named tag the diver already had in
  /// the list, which turning the switch off must leave alone.
  bool _autoTagAddedChip = false;

  /// This bundle's default tag name, fixed until [initializeDefaultTag]
  /// installs the next bundle.
  ///
  /// Adapters build this string from `DateTime.now()`, so re-deriving it on
  /// every read would drift to tomorrow's date if the review step is left
  /// open across midnight: the Import Options switch would then look for a
  /// name that no longer matches the chip already sitting in
  /// [ImportWizardState.importTags], and add a second tag when turned back
  /// on instead of toggling the original.
  String? _defaultTagName;

  /// The adapter's default "{source} Import {date}" tag name for the current
  /// bundle (issue #998 follow-up). Stable within a review session -- see
  /// [_defaultTagName].
  String get defaultTagName => _defaultTagName ??= _adapter.defaultTagName;

  /// The Import Options sheet's "tag this import" switch: whether
  /// auto-tagging applies to this import. See
  /// [ImportWizardState.autoTagThisImport].
  bool get isAutoTagForThisImportEnabled => state.autoTagThisImport;

  /// Adds or removes this bundle's default tag, for the Import Options
  /// sheet's live switch (issue #998 follow-up).
  ///
  /// Session-only: unlike the diver's saved [AppSettings.autoTagImports]
  /// preference that seeds every new import, toggling this never writes
  /// back to that setting -- it only changes the tag list for the import
  /// already in progress.
  ///
  /// Turning it on when a tag with the default name is already in the list
  /// adds no duplicate, and turning it off again leaves that tag in place:
  /// the diver put it there, not auto-tagging.
  void setAutoTagForThisImport(bool enabled) {
    if (enabled == state.autoTagThisImport) return;

    final defaultName = defaultTagName;
    final index = state.importTags.indexWhere(
      (t) => _sameTagName(t.name, defaultName),
    );
    if (enabled) {
      _autoTagAddedChip = index == -1;
      state = state.copyWith(
        autoTagThisImport: true,
        importTags: _autoTagAddedChip
            ? [...state.importTags, TagSelection(name: defaultName)]
            : null,
      );
    } else {
      final removeChip = _autoTagAddedChip && index != -1;
      _autoTagAddedChip = false;
      state = state.copyWith(
        autoTagThisImport: false,
        importTags: removeChip
            ? (List<TagSelection>.from(state.importTags)..removeAt(index))
            : null,
      );
    }
  }

  static bool _sameTagName(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  /// Add a tag to the import list.
  ///
  /// Silently ignores duplicates (case-insensitive name match).
  void addImportTag(TagSelection tag) {
    final alreadyExists = state.importTags.any(
      (t) => _sameTagName(t.name, tag.name),
    );
    if (alreadyExists) return;

    state = state.copyWith(importTags: [...state.importTags, tag]);
  }

  /// Remove a tag from the import list by index.
  ///
  /// Deleting the default chip while auto-tagging applies turns the Import
  /// Options switch off with it, so the switch never claims a tag the import
  /// no longer carries.
  void removeImportTag(int index) {
    if (index < 0 || index >= state.importTags.length) return;
    final removesDefault =
        state.autoTagThisImport &&
        _sameTagName(state.importTags[index].name, defaultTagName);
    if (removesDefault) _autoTagAddedChip = false;
    final updated = List<TagSelection>.from(state.importTags)..removeAt(index);
    state = state.copyWith(
      importTags: updated,
      autoTagThisImport: removesDefault ? false : null,
    );
  }

  // -------------------------------------------------------------------------
  // Duplicate action management
  // -------------------------------------------------------------------------

  /// Set the [action] for a specific duplicate item.
  ///
  /// In addition to recording the action, this also:
  /// - Syncs [ImportWizardState.selections] for [type]: removes [index] when
  ///   [action] is [DuplicateAction.skip]; adds [index] otherwise.
  /// - Drains [index] from [ImportWizardState.pendingDuplicateReview] for
  ///   [type] via [_drainPending].
  /// The profile this import writes to, for the planned-dive candidates
  /// (issue #2002). Null in an unscoped library.
  String? get diverId => _diverId;

  /// Point a planned-fill row at another planned dive, or (null) at none.
  /// Rewrites the bundle so the card and the adapter read one source of
  /// truth.
  ///
  /// A row that loses its target stops being a match at all: its match
  /// result and duplicate flag are removed and it imports as an ordinary
  /// new dive. Keeping a match with an empty dive id would not do, since an
  /// empty id already means "duplicate of another dive in this batch" to
  /// the comparison card.
  void setPlannedFillTarget(int index, String? plannedDiveId) {
    const type = ImportEntityType.dives;
    final bundle = state.bundle;
    final group = bundle?.groups[type];
    final current = group?.matchResults?[index];
    if (bundle == null || group == null || current == null) return;

    final EntityGroup updatedGroup;
    if (plannedDiveId == null) {
      updatedGroup = group.copyWith(
        duplicateIndices: group.duplicateIndices.difference({index}),
        matchResults: {
          for (final entry in group.matchResults!.entries)
            if (entry.key != index) entry.key: entry.value,
        },
      );
    } else {
      updatedGroup = group.copyWith(
        matchResults: {
          ...group.matchResults!,
          index: current.withPlannedDive(plannedDiveId),
        },
      );
    }
    state = state.copyWith(
      bundle: bundle.copyWith(groups: {...bundle.groups, type: updatedGroup}),
    );

    if (plannedDiveId != null) {
      setDuplicateAction(type, index, DuplicateAction.fillPlanned);
      return;
    }
    // No longer a duplicate: drop its action, keep it selected for import.
    final actions = Map<int, DuplicateAction>.from(
      state.duplicateActions[type] ?? const <int, DuplicateAction>{},
    )..remove(index);
    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: actions},
      selections: {
        ...state.selections,
        type: {...state.selections[type] ?? const <int>{}, index},
      },
      pendingDuplicateReview: _drainPending(type, {index}),
    );
  }

  void setDuplicateAction(
    ImportEntityType type,
    int index,
    DuplicateAction action,
  ) {
    assert(
      _adapter.duplicateActionsFor(type).contains(action),
      'DuplicateAction $action is not supported by adapter '
      '${_adapter.runtimeType} for entity type $type',
    );
    if (!_adapter.duplicateActionsFor(type).contains(action)) return;
    // A copy of another row in this import has no stored dive to fold into:
    // consolidating it would target an empty dive id.
    if (action == DuplicateAction.consolidate &&
        state.bundle?.groups[type]?.matchResults?[index]?.inBatchIndex !=
            null) {
      return;
    }

    final actionsForType =
        state.duplicateActions[type] ?? const <int, DuplicateAction>{};
    final updatedActions = Map<int, DuplicateAction>.from(actionsForType)
      ..[index] = action;

    final currentSelection = Set<int>.from(
      state.selections[type] ?? const <int>{},
    );
    if (action == DuplicateAction.skip) {
      currentSelection.remove(index);
    } else {
      currentSelection.add(index);
    }

    // A copy of another dive in this same import (#3110): the two are one
    // dive, so keeping this copy drops the other and skipping it brings the
    // other back. Ticking the other row again still keeps both.
    // A partner that is itself a flagged row has its own decision, which this
    // one must not overrule.
    final group = state.bundle?.groups[type];
    final partner = group?.matchResults?[index]?.inBatchIndex;
    if (partner != null && !group!.duplicateIndices.contains(partner)) {
      // Another copy of the same dive still kept means the partner stays
      // out: bringing it back would import that dive twice.
      final anotherCopyKept = updatedActions.entries.any(
        (e) =>
            e.key != index &&
            e.value == DuplicateAction.importAsNew &&
            group.matchResults?[e.key]?.inBatchIndex == partner,
      );
      if (action == DuplicateAction.importAsNew) {
        currentSelection.remove(partner);
      } else if (action == DuplicateAction.skip && !anotherCopyKept) {
        currentSelection.add(partner);
      }
    }

    final updatedPending = _drainPending(type, {index});

    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: updatedActions},
      selections: {...state.selections, type: currentSelection},
      pendingDuplicateReview: updatedPending,
    );
  }

  /// Returns a new pending-review map with the given indices removed from
  /// the set for [type]. If the resulting set is empty, the type key is
  /// removed from the map entirely (keeps `hasPendingReviews` fast).
  Map<ImportEntityType, Set<int>> _drainPending(
    ImportEntityType type,
    Set<int> indices,
  ) {
    final current = state.pendingFor(type);
    if (current.isEmpty) return state.pendingDuplicateReview;
    final updated = current.difference(indices);
    final newMap = Map<ImportEntityType, Set<int>>.from(
      state.pendingDuplicateReview,
    );
    if (updated.isEmpty) {
      newMap.remove(type);
    } else {
      newMap[type] = updated;
    }
    return newMap;
  }

  /// Apply [action] to every pending-review index for [type] in a single
  /// state update.
  ///
  /// For [DuplicateAction.consolidate], only indices whose
  /// `DiveMatchResult.score >= 0.7` AND whose
  /// `DiveMatchResult.matchedExistingSource` is false are consolidated;
  /// weaker matches and exact-source-hit re-downloads remain pending. For
  /// other actions, every pending index is affected.
  ///
  /// No-op if the type has no pending indices or (for consolidate) no
  /// eligible matches.
  void applyBulkAction(ImportEntityType type, DuplicateAction action) {
    assert(
      _adapter.duplicateActionsFor(type).contains(action),
      'DuplicateAction $action is not supported by adapter '
      '${_adapter.runtimeType} for entity type $type',
    );
    if (!_adapter.duplicateActionsFor(type).contains(action)) return;
    // One planned dive per row, chosen per row: never applied in bulk.
    if (action == DuplicateAction.fillPlanned) return;

    final pending = state.pendingFor(type);
    if (pending.isEmpty) return;

    final Set<int> affected;
    if (action == DuplicateAction.consolidate) {
      final matchResults = state.bundle?.groups[type]?.matchResults;
      if (matchResults == null) return;
      affected = pending.where((i) {
        final match = matchResults[i];
        // A matchedExistingSource hit is a re-download of data the matched
        // dive already has -- never a valid consolidate target, no matter
        // the score. An in-batch match has no existing dive to fold into.
        return match != null &&
            match.score >= 0.7 &&
            !match.matchedExistingSource &&
            match.inBatchIndex == null;
      }).toSet();
    } else {
      affected = pending;
    }

    if (affected.isEmpty) return;

    final actionsForType =
        state.duplicateActions[type] ?? const <int, DuplicateAction>{};
    final updatedActions = Map<int, DuplicateAction>.from(actionsForType);
    final currentSelection = Set<int>.from(
      state.selections[type] ?? const <int>{},
    );
    for (final i in affected) {
      updatedActions[i] = action;
      if (action == DuplicateAction.skip) {
        currentSelection.remove(i);
      } else {
        currentSelection.add(i);
      }
    }

    final updatedPending = _drainPending(type, affected);

    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: updatedActions},
      selections: {...state.selections, type: currentSelection},
      pendingDuplicateReview: updatedPending,
    );
  }

  /// Location of the first pending-review row across all entity tabs in
  /// [ImportEntityType.values] enum order. Returns the smallest index within
  /// the first non-empty pending set. Returns null if no pending rows exist.
  ///
  /// Used by the review step UI to jump the user to the first row that
  /// still needs a decision when the Import button is gated.
  PendingLocation? firstPendingLocation() {
    for (final type in ImportEntityType.values) {
      final pending = state.pendingFor(type);
      if (pending.isEmpty) continue;
      final sorted = pending.toList()..sort();
      return PendingLocation(type: type, index: sorted.first);
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  /// Run the import via the adapter.
  ///
  /// Sets [ImportWizardState.isImporting] to true during the operation,
  /// stores the result on success, or sets [ImportWizardState.error] on
  /// failure. Advances [currentStep] past the importing step on success.
  Future<void> performImport() async {
    // A change of profile is re-checking the rows (issue #2050); importing
    // now would apply the previous profile's choices.
    if (state.isRetargeting) return;
    final bundle = state.bundle;
    if (bundle == null) {
      state = state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'No import data available',
        ),
      );
      return;
    }

    final job = _job;
    final ImportCancellationToken token;
    if (job == null) {
      token = ImportCancellationToken();
    } else {
      final started = job.start(
        continuesWithoutWizard: _continuesWithoutWizard,
      );
      if (started == null) {
        // English for the log only; the summary shows a translated notice.
        const refused = 'Another import is still running';
        state = state.copyWith(
          importRefused: true,
          error: refused,
          importResult: const UnifiedImportResult(
            importedCounts: {},
            consolidatedCount: 0,
            skippedCount: 0,
            errorMessage: refused,
          ),
        );
        return;
      }
      token = started;
    }

    UnifiedImportResult? written;
    try {
      _cancelToken = token;
      // Read now: the diver may leave the wizard before the import ends, and
      // the tags must still reach the dives then.
      final importTags = state.importTags;

      state = state.copyWith(
        isImporting: true,
        isCancellationRequested: false,
        clearError: true,
      );

      final result = await _adapter.performImport(
        bundle,
        state.selections,
        state.duplicateActions,
        // A source with no numbers has nothing to retain; the review step
        // disables the option for it, and this keeps a stale "on" from
        // reaching the adapter anyway (issue #1832).
        retainSourceDiveNumbers:
            state.retainSourceDiveNumbers && bundle.hasSourceDiveNumbers,
        onProgress: (phase, current, total) =>
            _report(token, phase, current, total),
        cancelToken: token,
      );
      written = result;
      // The last photo phase would otherwise sit at 100% while the work
      // below runs (#3555).
      _report(token, ImportPhase.finishing, 0, 0);

      // Apply import tags to all imported dives.
      // Tag application is non-fatal: dives are already imported, so we
      // keep the result and advance to summary even if tagging fails.
      // Skip it entirely if cancellation was requested — the user asked
      // us to stop, not to do one more round of DB work.
      String? tagWarning;
      if (!token.isCancelled &&
          importTags.isNotEmpty &&
          (result.importedDiveIds.isNotEmpty ||
              result.diverOutcomes.any((o) => o.diveIds.isNotEmpty)) &&
          _tagRepository != null) {
        try {
          await _applyImportTags(result, importTags);
        } catch (e) {
          _log.warning('Tag application failed after import: $e');
          tagWarning = 'Dives imported successfully but tagging failed: $e';
        }
      }

      // Logbook rules run once the import has written everything (#3513);
      // like tagging, a failure keeps the import.
      final engine = _ruleEngine;
      _report(token, ImportPhase.finishing, 0, 0);
      final rules = token.isCancelled || engine == null
          ? const ImportRulesOutcome()
          : await runImportRules(
              engine,
              result,
              activeDiverId: _diverId,
              sourceLabel: _adapter.displayName,
              isCancelled: () => token.isCancelled,
            );

      // Once the wizard is gone the job reports the outcome instead.
      if (!mounted) return;
      state = state.copyWith(
        isImporting: false,
        importResult: result,
        currentStep: state.currentStep + 1,
        error: tagWarning,
        ruleRuns: rules.runs,
        rulesFailed: rules.failed,
        ruleSkippedRules: rules.skippedRules,
        ruleSkippedActions: rules.skippedActions,
      );
    } catch (e, stackTrace) {
      // The summary shows only the message; the trace is what finds the
      // failing lookup when a diver reports it (issue #3343).
      _log.error('Import failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      state = state.copyWith(
        isImporting: false,
        error: 'Import failed: $e',
        importResult: UnifiedImportResult(
          importedCounts: const {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Import failed: $e',
        ),
      );
    } finally {
      _cancelToken = null;
      // Refreshes the imported lists, wizard or not, and records how a job
      // that outlived its wizard ended.
      job?.finish(token, result: written, sourceType: _adapter.sourceType);
      if (mounted && state.isCancellationRequested) {
        state = state.copyWith(isCancellationRequested: false);
      }
    }
  }

  /// Passes progress to the job, and to this wizard while it is still open.
  void _report(
    ImportCancellationToken token,
    ImportPhase phase,
    int current,
    int total,
  ) {
    _job?.report(token, phase, current, total);
    // The importer keeps reporting after the diver leaves the wizard
    // (#3554). Only this copy of the progress has nowhere to go then;
    // throwing here would stop the importer's loop part-way.
    if (!mounted) return;
    state = state.copyWith(
      importPhase: phase,
      importCurrent: current,
      importTotal: total,
    );
  }

  /// Resolve tag selections and apply them to every imported dive.
  ///
  /// A tag belongs to one diver, so when an import wrote to several
  /// profiles (issue #1893) each profile gets its own tag of the chosen
  /// name. The existing tags offered in Review are the active diver's, so
  /// they are used as they are only for that diver's dives.
  Future<void> _applyImportTags(
    UnifiedImportResult result,
    List<TagSelection> importTags,
  ) async {
    final divesByDiver = <String?, List<String>>{
      if (result.diverOutcomes.isEmpty)
        _diverId: result.importedDiveIds
      else
        for (final outcome in result.diverOutcomes)
          if (outcome.diveIds.isNotEmpty) outcome.diverId: outcome.diveIds,
    };
    final total = divesByDiver.values.fold<int>(0, (n, ids) => n + ids.length);
    if (mounted) {
      state = state.copyWith(
        importPhase: ImportPhase.applyingTags,
        importCurrent: 0,
        importTotal: total,
      );
    }

    var done = 0;
    for (final MapEntry(key: diverId, value: diveIds) in divesByDiver.entries) {
      // Resolve tag selections to this diver's tag IDs.
      final tagIds = <String>[];
      for (final tagSelection in importTags) {
        if (!tagSelection.isNew && diverId == _diverId) {
          tagIds.add(tagSelection.existingTagId!);
        } else {
          final tag = await _tagRepository!.getOrCreateTag(
            tagSelection.name,
            diverId: diverId,
          );
          tagIds.add(tag.id);
        }
      }

      // Apply each tag to each of the diver's imported dives.
      for (final diveId in diveIds) {
        for (final tagId in tagIds) {
          await _tagRepository!.addTagToDive(diveId, tagId);
        }
        done++;
        if (mounted) state = state.copyWith(importCurrent: done);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  /// Return to the initial state.
  void reset() {
    _defaultTagSeeded = false;
    _autoTagAddedChip = false;
    _defaultTagName = null;
    state = const ImportWizardState();
  }

  /// Replace the notifier's state directly. Intended for widget tests that
  /// need to seed an arbitrary state (e.g. pending-review rows) without going
  /// through the full [setBundle] flow.
  @visibleForTesting
  void debugSetState(ImportWizardState newState) {
    state = newState;
  }
}

// ============================================================================
// Provider
// ============================================================================

/// Placeholder provider for the import wizard notifier.
///
/// Override this via [ProviderScope] for each wizard instance, supplying
/// the appropriate [ImportSourceAdapter].
final importWizardNotifierProvider =
    StateNotifierProvider<ImportWizardNotifier, ImportWizardState>((ref) {
      throw UnsupportedError(
        'importWizardNotifierProvider must be overridden with a ProviderScope '
        'that supplies an ImportSourceAdapter.',
      );
    });
