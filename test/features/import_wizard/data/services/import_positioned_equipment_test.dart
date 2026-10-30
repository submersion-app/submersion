import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/import_wizard/data/services/import_positioned_equipment.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

/// Records what it is asked to re-equip instead of touching a database.
class _RecordingDefaulter extends DiveEquipmentDefaulter {
  final calls = <({List<String> ids, bool replaceDefault})>[];

  @override
  Future<void> applyForPositionedDives(
    List<String> diveIds, {
    required bool replaceDefault,
  }) async {
    calls.add((ids: diveIds, replaceDefault: replaceDefault));
  }
}

PlannedDiveFillOutcome _fill(String diveId) => PlannedDiveFillOutcome(
  diveId: diveId,
  snapshot: DiveMergeSnapshot(
    mergedDiveId: diveId,
    diveRows: const [],
    tankRows: const [],
    weightRows: const [],
    customFieldRows: const [],
    equipmentRows: const [],
    diveTypeRows: const [],
    tagRows: const [],
    buddyRows: const [],
    sightingRows: const [],
    eventRows: const [],
    gasSwitchRows: const [],
    dataSourceRows: const [],
    tideRows: const [],
    mediaDiveIds: const {},
  ),
  assignedDiveNumber: null,
);

void main() {
  late _RecordingDefaulter defaulter;

  setUp(() => defaulter = _RecordingDefaulter());

  Future<void> reequip(
    UnifiedImportResult result,
    List<String> positioned, {
    ImportSourceType sourceType = ImportSourceType.diveComputer,
  }) => reequipPositionedDives(
    defaulter,
    result,
    positionedDiveIds: positioned,
    sourceType: sourceType,
  );

  test('re-equips only the positioned dives the import created', () async {
    await reequip(
      UnifiedImportResult(
        importedCounts: const {},
        consolidatedCount: 0,
        skippedCount: 0,
        importedDiveIds: const ['new', 'plan', 'not-positioned'],
        updatedExistingDiveIds: const ['merged'],
        fillOutcomes: [_fill('plan')],
        diverOutcomes: const [
          DiverImportOutcome(
            diverId: 'buddy',
            name: 'Buddy',
            isNew: false,
            isActive: false,
            diveIds: ['buddy-new'],
          ),
        ],
      ),
      ['new', 'plan', 'merged', 'buddy-new'],
    );

    // A filled plan keeps the diver's gear; a merged-into dive keeps its own.
    expect(defaulter.calls.single.ids, unorderedEquals(['new', 'buddy-new']));
  });

  test('a download may replace the default set; a file import may not, '
      'since its gear can be the diver\'s own choice', () async {
    const result = UnifiedImportResult(
      importedCounts: {},
      consolidatedCount: 0,
      skippedCount: 0,
      importedDiveIds: ['new'],
    );

    await reequip(result, ['new']);
    await reequip(result, ['new'], sourceType: ImportSourceType.garminCloud);
    await reequip(result, ['new'], sourceType: ImportSourceType.uddf);
    await reequip(result, ['new'], sourceType: ImportSourceType.universal);

    expect(
      [for (final c in defaulter.calls) c.replaceDefault],
      [true, true, false, false],
    );
  });

  test('nothing positioned, nothing re-equipped', () async {
    await reequip(
      const UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        importedDiveIds: ['new'],
      ),
      const [],
    );

    expect(defaulter.calls, isEmpty);
  });
}
