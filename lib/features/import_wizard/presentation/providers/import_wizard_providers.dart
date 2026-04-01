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
