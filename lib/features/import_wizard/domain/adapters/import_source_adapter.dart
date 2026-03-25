import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Interface for source-specific import adapters.
///
/// Each import source (dive computer, UDDF, FIT, HealthKit, Universal)
/// implements this interface to plug into the [UnifiedImportWizard].
/// The adapter provides source-specific acquisition steps, normalizes
/// acquired data into an [ImportBundle], and handles the actual import.
abstract class ImportSourceAdapter {
  /// The type of import source this adapter handles.
  ImportSourceType get sourceType;

  /// Display name for the source (e.g., "Shearwater Perdix", "dive_log.uddf").
  String get displayName;

  /// Source-specific acquisition step definitions.
  ///
  /// These steps are shown before the shared Review/Import/Summary steps.
  /// Each step's [WizardStepDef.canAdvance] provider signals when the wizard
  /// can proceed to the next step.
  List<WizardStepDef> get acquisitionSteps;

  /// Which duplicate actions are available for this source's dives.
  ///
  /// Dive computer sources support [DuplicateAction.consolidate];
  /// file-based sources typically support only skip and importAsNew.
  Set<DuplicateAction> get supportedDuplicateActions;

  /// Normalize acquired data into the common [ImportBundle] model.
  Future<ImportBundle> buildBundle();

  /// Run duplicate detection against the existing database.
  ///
  /// Returns an updated [ImportBundle] with [EntityGroup.duplicateIndices]
  /// and [EntityGroup.matchResults] populated.
  Future<ImportBundle> checkDuplicates(ImportBundle bundle);

  /// Save selected items using the raw source data.
  ///
  /// The [selections] map contains which items the user selected per entity
  /// type. The [duplicateActions] map contains the user's chosen action for
  /// each duplicate item per entity type.
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers,
    void Function(String phase, int current, int total)? onProgress,
  });
}
