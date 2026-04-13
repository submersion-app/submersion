import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
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

  /// Set the validated diver ID for tag association during import.
  void setDiverId(String? diverId) {
    _diverId = diverId;
  }

  /// The duplicate actions supported by the underlying adapter.
  Set<DuplicateAction> get supportedDuplicateActions =>
      _adapter.supportedDuplicateActions;

  // -------------------------------------------------------------------------
  // setBundle
  // -------------------------------------------------------------------------

  /// Store [bundle] and initialize selections and pending-review state.
  ///
  /// For each entity group:
  /// - All items are selected except those in [EntityGroup.duplicateIndices].
  /// - Every suspected-duplicate index is recorded in
  ///   [ImportWizardState.pendingDuplicateReview] so the user must explicitly
  ///   choose an action before the row gets a recorded resolution.
  /// - [ImportWizardState.duplicateActions] is left empty — no auto-defaults
  ///   are written for probable or possible matches. The user drains the
  ///   pending set via per-row ([setDuplicateAction]) or bulk actions.
  void setBundle(ImportBundle bundle) {
    final selections = <ImportEntityType, Set<int>>{};
    final pendingReview = <ImportEntityType, Set<int>>{};

    for (final entry in bundle.groups.entries) {
      final type = entry.key;
      final group = entry.value;

      final allIndices = Set<int>.from(
        List.generate(group.items.length, (i) => i),
      );
      selections[type] = allIndices.difference(group.duplicateIndices);

      if (group.duplicateIndices.isNotEmpty) {
        pendingReview[type] = Set<int>.from(group.duplicateIndices);
      }
    }

    state = state.copyWith(
      bundle: bundle,
      selections: selections,
      // Auto-default duplicateActions removed — pending indices are decided
      // explicitly by the user via setDuplicateAction or applyBulkAction.
      duplicateActions: const {},
      pendingDuplicateReview: pendingReview,
      currentStep: 1,
      clearError: true,
    );
  }

  // -------------------------------------------------------------------------
  // Selection management
  // -------------------------------------------------------------------------

  /// Toggle the selection of a single item.
  void toggleSelection(ImportEntityType type, int index) {
    final current = state.selections[type] ?? const <int>{};
    final updated = Set<int>.from(current);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }

    final updatedPending = _drainPending(type, {index});

    state = state.copyWith(
      selections: {...state.selections, type: updated},
      pendingDuplicateReview: updatedPending,
    );
  }

  /// Select all non-duplicate items for [type].
  void selectAll(ImportEntityType type) {
    final group = state.bundle?.groups[type];
    if (group == null) return;

    final allIndices = Set<int>.from(
      List.generate(group.items.length, (i) => i),
    );
    final nonDuplicates = allIndices.difference(group.duplicateIndices);

    state = state.copyWith(
      selections: {...state.selections, type: nonDuplicates},
    );
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
      _adapter.supportedDuplicateActions.contains(action),
      'DuplicateAction $action is not supported by adapter '
      '${_adapter.runtimeType}',
    );
    if (!_adapter.supportedDuplicateActions.contains(action)) return;

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
  /// `DiveMatchResult.score >= 0.7` are consolidated; weaker matches remain
  /// pending. For other actions, every pending index is affected.
  ///
  /// No-op if the type has no pending indices or (for consolidate) no
  /// probable matches.
  void applyBulkAction(ImportEntityType type, DuplicateAction action) {
    assert(
      _adapter.supportedDuplicateActions.contains(action),
      'DuplicateAction $action is not supported by adapter '
      '${_adapter.runtimeType}',
    );
    if (!_adapter.supportedDuplicateActions.contains(action)) return;

    final pending = state.pendingFor(type);
    if (pending.isEmpty) return;

    final Set<int> affected;
    if (action == DuplicateAction.consolidate) {
      final matchResults = state.bundle?.groups[type]?.matchResults;
      if (matchResults == null) return;
      affected = pending.where((i) {
        final match = matchResults[i];
        return match != null && match.score >= 0.7;
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

    state = state.copyWith(isImporting: true, clearError: true);

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
      );

      // Apply import tags to all imported dives.
      // Tag application is non-fatal: dives are already imported, so we
      // keep the result and advance to summary even if tagging fails.
      String? tagWarning;
      if (state.importTags.isNotEmpty &&
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
