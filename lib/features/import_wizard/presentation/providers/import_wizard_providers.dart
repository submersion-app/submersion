import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

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
    this.retainSourceDiveNumbers = false,
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

  /// When true, imported dives keep their original dive numbers from the
  /// source file instead of being auto-assigned sequential numbers.
  final bool retainSourceDiveNumbers;

  /// Human-readable label for the current import phase (e.g. "dives").
  final String? importPhase;

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
    bool? retainSourceDiveNumbers,
    String? importPhase,
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
      retainSourceDiveNumbers:
          retainSourceDiveNumbers ?? this.retainSourceDiveNumbers,
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
}

// ============================================================================
// Notifier
// ============================================================================

/// Manages the post-acquisition state of the unified import wizard.
///
/// Orchestrates review selections, duplicate actions, import progress,
/// and results. Source-specific logic is delegated to an [ImportSourceAdapter].
class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  ImportWizardNotifier(this._adapter) : super(const ImportWizardState());

  final ImportSourceAdapter _adapter;

  /// The duplicate actions supported by the underlying adapter.
  Set<DuplicateAction> get supportedDuplicateActions =>
      _adapter.supportedDuplicateActions;

  // -------------------------------------------------------------------------
  // setBundle
  // -------------------------------------------------------------------------

  /// Store [bundle] and initialize selections and duplicate actions.
  ///
  /// For each entity group:
  /// - All items are selected except those in [EntityGroup.duplicateIndices].
  ///
  /// For dives with [EntityGroup.matchResults]:
  /// - score >= 0.7 → [DuplicateAction.skip]
  /// - score >= 0.5 and < 0.7 → [DuplicateAction.importAsNew]
  void setBundle(ImportBundle bundle) {
    final selections = <ImportEntityType, Set<int>>{};
    final duplicateActions = <ImportEntityType, Map<int, DuplicateAction>>{};

    for (final entry in bundle.groups.entries) {
      final type = entry.key;
      final group = entry.value;

      // Build initial selection: all indices except duplicates.
      final allIndices = Set<int>.from(
        List.generate(group.items.length, (i) => i),
      );
      selections[type] = allIndices.difference(group.duplicateIndices);

      // Build duplicate actions from match results.
      final matchResults = group.matchResults;
      if (matchResults != null && matchResults.isNotEmpty) {
        final actionsForType = <int, DuplicateAction>{};
        for (final matchEntry in matchResults.entries) {
          final index = matchEntry.key;
          final result = matchEntry.value;
          if (result.isProbable) {
            actionsForType[index] = DuplicateAction.skip;
          } else if (result.score >= 0.5) {
            // Possible but not probable — default to import as new.
            actionsForType[index] = DuplicateAction.importAsNew;
          }
        }
        if (actionsForType.isNotEmpty) {
          duplicateActions[type] = actionsForType;
        }
      }
    }

    state = state.copyWith(
      bundle: bundle,
      selections: selections,
      duplicateActions: duplicateActions,
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
    state = state.copyWith(selections: {...state.selections, type: updated});
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
  // Duplicate action management
  // -------------------------------------------------------------------------

  /// Set the [action] for a specific duplicate item.
  void setDuplicateAction(
    ImportEntityType type,
    int index,
    DuplicateAction action,
  ) {
    final current =
        state.duplicateActions[type] ?? const <int, DuplicateAction>{};
    final updated = Map<int, DuplicateAction>.from(current)..[index] = action;
    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: updated},
    );
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
    if (bundle == null) return;

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

      state = state.copyWith(
        isImporting: false,
        importResult: result,
        currentStep: state.currentStep + 1,
      );
    } catch (e) {
      state = state.copyWith(isImporting: false, error: 'Import failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  /// Return to the initial state.
  void reset() {
    state = const ImportWizardState();
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
