import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A replaceSource re-download matches an existing dive, so importProfile takes
/// the isNewDive == false branch and the creation-seam trio never runs. The
/// computer still logged the dive, so its gear twin belongs on it.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repo = DiveComputerRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear-1',
            name: 'gear-1',
            type: 'computer',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: 'c1',
            equipmentId: const Value('gear-1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('re-importing onto an existing dive links the gear twin', () async {
    final start = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    final diveId = await repo.importProfile(
      computerId: 'c1',
      profileStartTime: start,
      points: const [],
      durationSeconds: 1800,
      maxDepth: 30.0,
    );

    // Remove the link so the second pass has something to prove.
    await (db.delete(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).go();
    await repo.clearSourceAndProfiles(diveId: diveId, computerId: 'c1');
    expect(await equipmentOn(diveId), isEmpty);

    // Second import matches the same dive: the isNewDive == false branch.
    final again = await repo.importProfile(
      computerId: 'c1',
      profileStartTime: start,
      points: const [],
      durationSeconds: 1800,
      maxDepth: 30.0,
    );

    expect(again, diveId);
    expect(await equipmentOn(diveId), contains('gear-1'));
  });
}
