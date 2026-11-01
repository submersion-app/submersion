// Issue #3422: the table editor edits one dive's single weight row in place.
// WeightAmountOp carries an amount (or null to drop the row) and the type a
// row created from an empty cell takes.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
  );

  domain.DiveWeight weight(double kg, {WeightType type = WeightType.belt}) =>
      domain.DiveWeight(id: '', diveId: '', weightType: type, amountKg: kg);

  Future<List<DiveWeight>> rowsOf(String d) =>
      (db.select(db.diveWeights)..where((t) => t.diveId.equals(d))).get();

  Future<List<double>> weightsOf(String d) async =>
      (await rowsOf(d)).map((r) => r.amountKg).toList();

  Future<List<String>> tombstones() async =>
      (await db.select(db.deletionLog).get()).map((d) => d.recordId).toList();

  Future<BulkEditSnapshot> applyAmount(
    String id,
    double? amountKg, {
    WeightType newRowType = WeightType.belt,
  }) => service.apply(
    BulkEditRequest(
      diveIds: [id],
      ops: [WeightAmountOp(amountKg: amountKg, newRowType: newRowType)],
    ),
  );

  test(
    'getWeightsForDives groups rows by dive and omits dives without',
    () async {
      await seed('d1');
      await seed('d2');
      await diveRepo.bulkAddWeights(['d1'], [weight(3), weight(4)]);

      final byDive = await diveRepo.getWeightsForDives(['d1', 'd2']);

      expect(byDive.keys, ['d1']);
      expect(byDive['d1']!.map((w) => w.amountKg), [3, 4]);
    },
  );

  test(
    'WeightAmountOp inserts one row of the given type on a dive with none',
    () async {
      await seed('d1');

      await applyAmount('d1', 6, newRowType: WeightType.integrated);

      final rows = await rowsOf('d1');
      expect(rows, hasLength(1));
      expect(rows.single.amountKg, 6);
      expect(rows.single.weightType, 'integrated');
    },
  );

  test(
    'WeightAmountOp updates the single row in place and keeps its id',
    () async {
      await seed('d1');
      await diveRepo.bulkAddWeights(['d1'], [weight(3)]);
      final before = (await rowsOf('d1')).single;

      await applyAmount('d1', 8);

      final after = (await rowsOf('d1')).single;
      expect(after.id, before.id);
      expect(after.amountKg, 8);
      expect(await tombstones(), isNot(contains(before.id)));
    },
  );

  test('WeightAmountOp with null deletes the single row', () async {
    await seed('d1');
    await diveRepo.bulkAddWeights(['d1'], [weight(3)]);
    final before = (await rowsOf('d1')).single;

    await applyAmount('d1', null);

    expect(await weightsOf('d1'), isEmpty);
    expect(await tombstones(), contains(before.id));
  });

  test(
    'WeightAmountOp throws on a dive with two rows and changes nothing',
    () async {
      await seed('d1');
      await diveRepo.bulkAddWeights(['d1'], [weight(3), weight(4)]);

      await expectLater(applyAmount('d1', 9), throwsStateError);

      expect(await weightsOf('d1'), [3, 4]);
    },
  );

  test('undo after WeightAmountOp restores the prior rows', () async {
    await seed('d1');
    await diveRepo.bulkAddWeights(['d1'], [weight(3)]);

    final snap = await applyAmount('d1', 8);
    await service.undo(snap);

    expect(await weightsOf('d1'), [3]);
  });
}
