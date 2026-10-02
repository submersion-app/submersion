import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2716: a tank split leaves behind (another reference still needs
/// it) lets go of the source that left, and of no other.
void main() {
  late AppDatabase db;

  Future<void> source(String id, {required String computerId}) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: 'd1',
          importedAt: DateTime.utc(2026),
          createdAt: DateTime.utc(2026),
        ).copyWith(
          computerId: Value(computerId),
          isPrimary: Value(id == 'src-p'),
        ),
      );

  /// A tank of computer X held back by a gas switch, which always stays
  /// with the original dive's gas plan.
  Future<void> heldTank(String id, String sourceId, int order) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: id, diveId: 'd1').copyWith(
            computerId: const Value('x'),
            sourceId: Value(sourceId),
            tankOrder: Value(order),
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-$id',
            diveId: 'd1',
            timestamp: 60,
            tankId: id,
            createdAt: 0,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final id in ['p', 'x']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    // Two sources of computer X: the halves of a combined dive.
    await source('src-p', computerId: 'p');
    await source('src-x1', computerId: 'x');
    await source('src-x2', computerId: 'x');
    await heldTank('t1', 'src-x1', 0);
    await heldTank('t2', 'src-x2', 1);
  });

  tearDown(tearDownTestDatabase);

  test('a tank left behind drops only the source that left', () async {
    await DiveSplitService(
      DiveRepository(),
    ).split(diveId: 'd1', sourceId: 'src-x2');

    final kept = {
      for (final t in await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).get())
        t.id: t.sourceId,
    };
    expect(kept, {'t1': 'src-x1', 't2': null});
  });
}
