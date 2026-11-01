import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Removing a cylinder cascades every gas switch that names it, including
/// another computer's the editor never loaded (issue #32). SQLite performs
/// the cascade without Drift seeing a write, so the removal itself must
/// log the switches' deletions or a peer keeps them.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(tearDownTestDatabase);

  test('removing a cylinder tombstones every switch it carried', () async {
    final dive = await repository.createDive(
      domain.Dive(
        id: 'dive-1',
        dateTime: DateTime.utc(2026, 5, 3, 10),
        tanks: const [
          domain.DiveTank(id: 't-back', volume: 12),
          domain.DiveTank(id: 't-deco', volume: 7, order: 1),
        ],
      ),
    );
    await db
        .into(db.diveComputers)
        .insert(
          const DiveComputersCompanion(
            id: Value('comp-2'),
            name: Value('Other computer'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'gs-other',
            diveId: 'dive-1',
            tankId: 't-deco',
            timestamp: 600,
            createdAt: 0,
            computerId: const Value('comp-2'),
          ),
        );

    await repository.updateDive(dive.copyWith(tanks: [dive.tanks.first]));

    final switches = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals('dive-1'))).get();
    expect(switches, isEmpty);
    final tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('gasSwitches'))).get();
    expect(tombstones.map((t) => t.recordId), ['gs-other']);
  });
}
