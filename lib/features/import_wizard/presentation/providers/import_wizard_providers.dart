import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
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
    this.importTags = const [],
    this.importPhase,
    this.importCurrent = 0,
    this.importTotal = 0,
    this.importResult,
    this.isImporting = false,
    this.isCancellationRequested = false,
    this.error,
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

  /// Tags to apply to all imported dives.
  final List<TagSelection> importTags;

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

  ImportWizardState copyWith({
    int? currentStep,
    ImportBundle? bundle,
    bool clearBundle = false,
    Map<ImportEntityType, Set<int>>? selections,
    Map<ImportEntityType, Map<int, DuplicateAction>>? duplicateActions,
    Map<ImportEntityType, Set<int>>? pendingDuplicateReview,
    bool? retainSourceDiveNumbers,
    List<TagSelection>? importTags,
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
      importTags: importTags ?? this.importTags,
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
class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  ImportWizardNotifier(
    this._adapter, {
    TagRepository? tagRepository,
    String? diverId,
  }) : _tagRepository = tagRepository,
       _diverId = diverId,
       super(const ImportWizardState());

  static final _log = LoggerService.forClass(ImportWizardNotifier);

  final ImportSourceAdapter _adapter;
  final TagRepository? _tagRepository;
  String? _diverId;

  /// Active cancellation token for the currently-running import, or null
  /// when no import is in progress. The notifier owns the lifecycle: it's
  /// allocated fresh in [performImport] and cleared once the adapter returns.
  ImportCancellationToken? _cancelToken;

  /// Set the validated diver ID for tag association during import.
  void setDiverId(String? diverId) {
    _diverId = diverId;
  }

  /// Request cancellation of the running import. Cooperative — the adapter
  /// finishes the current work item (e.g. the current dive's transaction)
  /// before exiting the loop with a partial result.
  ///
  /// Safe to call when no import is in progress: it just no-ops.
  /// Safe to call repeatedly: the token's own `cancel()` is idempotent.
  void cancelImport() {
    final token = _cancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel();
    state = state.copyWith(isCancellationRequested: true);
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
  void setBundle(ImportBundle bundle) {
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

      if (pendingForType.isNotEmpty) {
        pendingReview[type] = pendingForType;
      }
    }

    state = state.copyWith(
      bundle: bundle,
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

  // -------------------------------------------------------------------------
  // Import tags
  // -------------------------------------------------------------------------

  /// Pre-populate [importTags] with the adapter's default tag.
  ///
  /// Safe to call multiple times — skips if a tag with the same name already
  /// exists.
  void initializeDefaultTag() {
    final defaultName = _adapter.defaultTagName;
    final alreadyExists = state.importTags.any(
      (t) => t.name.toLowerCase() == defaultName.toLowerCase(),
    );
    if (alreadyExists) return;

    state = state.copyWith(
      importTags: [
        ...state.importTags,
        TagSelection(name: defaultName),
      ],
    );
  }

  /// Add a tag to the import list.
  ///
  /// Silently ignores duplicates (case-insensitive name match).
  void addImportTag(TagSelection tag) {
    final alreadyExists = state.importTags.any(
      (t) => t.name.toLowerCase() == tag.name.toLowerCase(),
    );
    if (alreadyExists) return;

    state = state.copyWith(importTags: [...state.importTags, tag]);
  }

  /// Remove a tag from the import list by index.
  void removeImportTag(int index) {
    if (index < 0 || index >= state.importTags.length) return;
    final updated = List<TagSelection>.from(state.importTags)..removeAt(index);
    state = state.copyWith(importTags: updated);
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

    final token = ImportCancellationToken();
    _cancelToken = token;

    state = state.copyWith(
      isImporting: true,
      isCancellationRequested: false,
      clearError: true,
    );

    try {
      final result = await _adapter.performImport(
        bundle,
        state.selections,
        state.duplicateActions,
        retainSourceDiveNumbers: state.retainSourceDiveNumbers,
        onProgress: (phase, current, total) {
          state = state.copyWith(
            importPhase: phase,
            importCurrent: current,
            importTotal: total,
          );
        },
        cancelToken: token,
      );

      // Apply import tags to all imported dives.
      // Tag application is non-fatal: dives are already imported, so we
      // keep the result and advance to summary even if tagging fails.
      // Skip it entirely if cancellation was requested — the user asked
      // us to stop, not to do one more round of DB work.
      String? tagWarning;
      if (!token.isCancelled &&
          state.importTags.isNotEmpty &&
          result.importedDiveIds.isNotEmpty &&
          _tagRepository != null) {
        try {
          await _applyImportTags(result.importedDiveIds);
        } catch (e) {
          _log.warning('Tag application failed after import: $e');
          tagWarning = 'Dives imported successfully but tagging failed: $e';
        }
      }

      state = state.copyWith(
        isImporting: false,
        importResult: result,
        currentStep: state.currentStep + 1,
        error: tagWarning,
      );
    } catch (e) {
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
      if (state.isCancellationRequested) {
        state = state.copyWith(isCancellationRequested: false);
      }
    }
  }

  /// Resolve tag selections and apply them to the given dive IDs.
  Future<void> _applyImportTags(List<String> importedDiveIds) async {
    state = state.copyWith(
      importPhase: ImportPhase.applyingTags,
      importCurrent: 0,
      importTotal: importedDiveIds.length,
    );

    // Resolve tag selections to tag IDs.
    final tagIds = <String>[];
    for (final tagSelection in state.importTags) {
      if (tagSelection.isNew) {
        final tag = await _tagRepository!.getOrCreateTag(
          tagSelection.name,
          diverId: _diverId,
        );
        tagIds.add(tag.id);
      } else {
        tagIds.add(tagSelection.existingTagId!);
      }
    }

    // Apply each tag to each imported dive.
    for (var i = 0; i < importedDiveIds.length; i++) {
      final diveId = importedDiveIds[i];
      for (final tagId in tagIds) {
        await _tagRepository!.addTagToDive(diveId, tagId);
      }
      state = state.copyWith(importCurrent: i + 1);
    }
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  /// Return to the initial state.
  void reset() {
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
