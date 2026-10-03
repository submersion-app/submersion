import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';

/// Rewriting an assembly onto past dives changes their gear without a save,
/// so it queues the rescan that keeps shared gear findings current (issue
/// #2853).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    QualityScanScheduler.enabled = true;
    addTearDown(applyGlobalTestDefaults);
  });
  tearDown(tearDownTestDatabase);

  test('the rewritten dives are rescanned', () async {
    final db = DatabaseService.instance.database;
    final ten = DateTime.utc(2026, 5, 1, 10).millisecondsSinceEpoch;
    for (final id in ['bill', 'anna']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    for (final id in ['reg', 'octo']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'other',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('bill'),
            ),
          );
    }
    for (final (id, diver, at) in [
      ('b1', 'bill', ten),
      ('a1', 'anna', ten + 10 * 60 * 1000),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diverId: Value(diver),
              diveDateTime: at,
              createdAt: 1,
              updatedAt: 1,
              entryTime: Value(at),
              runtime: const Value(40 * 60),
            ),
          );
    }
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'b1', equipmentId: 'reg'),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'a1', equipmentId: 'octo'),
        );

    final touched = await DiveRepository().rewriteAssemblyOnPastDives('reg', [
      const GearPartAdded('octo'),
    ]);
    expect(touched, 1);
    await QualityScanScheduler.instance.idle;

    final findings = await QualityFindingsRepository().getFindings(
      diveId: 'b1',
    );
    expect(
      findings.map((f) => (f.detectorId, f.params['equipmentId'])),
      contains(('shared_gear_overlap', 'octo')),
    );
  });
}
