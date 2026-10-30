import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Returns [result], first running [during] as if the diver acted mid-import.
class _Adapter implements ImportSourceAdapter {
  _Adapter(this.result);

  final UnifiedImportResult result;
  void Function()? during;

  @override
  void resetState() {}
  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;
  @override
  String get displayName => 'Perdix 2';
  @override
  String get defaultTagName => 'Perdix 2 Import';
  @override
  List<WizardStepDef> get acquisitionSteps => [];
  @override
  Set<DuplicateAction> get supportedDuplicateActions => {DuplicateAction.skip};
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;
  @override
  Future<ImportBundle> buildBundle() => throw UnimplementedError();
  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) =>
      throw UnimplementedError();
  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    during?.call();
    return result;
  }
}

/// Records each sweep's ids instead of touching a database.
class _RecordingGpsTrackMatchService extends GpsTrackMatchService {
  _RecordingGpsTrackMatchService()
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );

  final sweeps = <List<String>?>[];

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    sweeps.add(limitToIds);
    return const [];
  }
}

const _bundle = ImportBundle(
  source: ImportSourceInfo(type: ImportSourceType.uddf, displayName: 'x.uddf'),
  groups: {},
);

const _imported = UnifiedImportResult(
  importedCounts: {ImportEntityType.dives: 1},
  consolidatedCount: 0,
  skippedCount: 0,
  importedDiveIds: ['d1'],
);

/// Issue #3704: the wizard positions the dives any source imported.
void main() {
  late _RecordingGpsTrackMatchService gps;
  late _Adapter adapter;
  late ImportWizardNotifier wizard;

  setUp(() {
    gps = _RecordingGpsTrackMatchService();
    adapter = _Adapter(_imported);
    wizard = ImportWizardNotifier(adapter, gpsTrackMatchService: gps)
      ..setBundle(_bundle);
  });

  test('sweeps the dives a file import wrote', () async {
    await wizard.performImport();

    expect(gps.sweeps, [
      ['d1'],
    ]);
  });

  test('a cancelled import sweeps nothing, as it applies no tags', () async {
    adapter.during = wizard.cancelImport;

    await wizard.performImport();

    expect(gps.sweeps, isEmpty);
  });
}
