import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart'
    as domain_field;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain_weight;

import '../../../../helpers/test_database.dart';

/// Issue #1727. `updateDive` used to delete every weight and custom field a
/// dive held and re-insert them, which published a deletion tombstone and a
/// pending mark for the same key in one sync round. Neither table carries an
/// `updatedAt` the merge can compare, so whichever a peer applied last decided
/// whether the row lived. Both children now diff on the row id, the way the
/// gear writer added in #1716 does.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  domain_weight.DiveWeight weight(
    String id,
    WeightType type,
    double kg, {
    String notes = '',
  }) => domain_weight.DiveWeight(
    id: id,
    diveId: 'dv',
    weightType: type,
    amountKg: kg,
    notes: notes,
  );

  Future<List<DiveWeight>> weightRows() async =>
      (await (db.select(db.diveWeights)
            ..where((t) => t.diveId.equals('dv'))
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get());

  Future<List<DiveCustomField>> customFieldRows() async =>
      (await (db.select(db.diveCustomFields)
            ..where((t) => t.diveId.equals('dv'))
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get());

  Future<List<String>> tombstonesFor(String entityType) async => [
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == entityType) t.recordId,
  ];

  Future<Set<String>> pendingFor(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
  };

  /// Pretends every pending row for [entityType] has reached the peers, so a
  /// later re-mark is visible as the row going pending again.
  Future<void> markEverythingSynced(String entityType) async {
    await (db.update(db.syncRecords)
          ..where((t) => t.entityType.equals(entityType)))
        .write(const SyncRecordsCompanion(syncStatus: Value('synced')));
  }

  Future<domain.Dive> seed({
    List<domain_weight.DiveWeight> weights = const [],
    List<domain_field.DiveCustomField> customFields = const [],
  }) async {
    await repo.createDive(
      domain.Dive(
        id: 'dv',
        dateTime: DateTime(2026, 1, 1),
        weights: weights,
        customFields: customFields,
      ),
    );
    return (await repo.getDiveById('dv'))!;
  }

  group('weights', () {
    test('an unchanged weight is neither tombstoned nor re-marked', () async {
      final dive = await seed(
        weights: [
          weight('w1', WeightType.belt, 4),
          weight('w2', WeightType.trimWeights, 1),
        ],
      );
      final createdAtBefore = {
        for (final r in await weightRows()) r.id: r.createdAt,
      };
      await markEverythingSynced('diveWeights');

      await repo.updateDive(dive);

      expect(
        await tombstonesFor('diveWeights'),
        isEmpty,
        reason: 'a row the save re-writes unchanged must not be tombstoned',
      );
      expect(await pendingFor('diveWeights'), isEmpty);
      expect(
        {for (final r in await weightRows()) r.id: r.createdAt},
        createdAtBefore,
        reason: 'an untouched row keeps its identity, not just its values',
      );
    });

    test('a changed weight is updated in place, not replaced', () async {
      final dive = await seed(weights: [weight('w1', WeightType.belt, 4)]);
      final createdAtBefore = (await weightRows()).single.createdAt;
      await markEverythingSynced('diveWeights');

      await repo.updateDive(
        dive.copyWith(
          weights: [weight('w1', WeightType.belt, 5, notes: 'one more block')],
        ),
      );

      expect(await tombstonesFor('diveWeights'), isEmpty);
      expect(await pendingFor('diveWeights'), {'w1'});
      final row = (await weightRows()).single;
      expect(row.amountKg, 5);
      expect(row.notes, 'one more block');
      expect(row.createdAt, createdAtBefore);
    });

    test('a removed weight is deleted and tombstoned', () async {
      final dive = await seed(
        weights: [
          weight('w1', WeightType.belt, 4),
          weight('w2', WeightType.trimWeights, 1),
        ],
      );
      await markEverythingSynced('diveWeights');

      await repo.updateDive(
        dive.copyWith(weights: [weight('w1', WeightType.belt, 4)]),
      );

      expect(await tombstonesFor('diveWeights'), ['w2']);
      expect((await weightRows()).map((r) => r.id), ['w1']);
      expect(await pendingFor('diveWeights'), isEmpty);
    });

    test('an added weight is inserted and marked pending', () async {
      final dive = await seed(weights: [weight('w1', WeightType.belt, 4)]);
      await markEverythingSynced('diveWeights');

      await repo.updateDive(
        dive.copyWith(
          weights: [
            weight('w1', WeightType.belt, 4),
            weight('w2', WeightType.ankleWeights, 0.5),
          ],
        ),
      );

      expect(await tombstonesFor('diveWeights'), isEmpty);
      expect(await pendingFor('diveWeights'), {'w2'});
      expect((await weightRows()).map((r) => r.id), ['w1', 'w2']);
    });

    test('a weight arriving without an id is inserted', () async {
      final dive = await seed(weights: [weight('w1', WeightType.belt, 4)]);

      await repo.updateDive(
        dive.copyWith(
          weights: [
            weight('w1', WeightType.belt, 4),
            weight('', WeightType.trimWeights, 1),
          ],
        ),
      );

      final rows = await weightRows();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.id), contains('w1'));
      expect(rows.every((r) => r.id.isNotEmpty), isTrue);
      expect(await tombstonesFor('diveWeights'), isEmpty);
    });
  });

  group('custom fields', () {
    domain_field.DiveCustomField field(
      String id,
      String key,
      String value, {
      int sort = 0,
    }) => domain_field.DiveCustomField(
      id: id,
      key: key,
      value: value,
      sortOrder: sort,
    );

    test(
      'an unchanged custom field is neither tombstoned nor re-marked',
      () async {
        final dive = await seed(
          customFields: [
            field('c1', 'Wetsuit', '5mm'),
            field('c2', 'Ferry', 'Ischia', sort: 1),
          ],
        );
        final createdAtBefore = {
          for (final r in await customFieldRows()) r.id: r.createdAt,
        };
        await markEverythingSynced('diveCustomFields');

        await repo.updateDive(dive);

        expect(await tombstonesFor('diveCustomFields'), isEmpty);
        expect(await pendingFor('diveCustomFields'), isEmpty);
        expect({
          for (final r in await customFieldRows()) r.id: r.createdAt,
        }, createdAtBefore);
      },
    );

    test('a changed custom field is updated in place, not replaced', () async {
      final dive = await seed(customFields: [field('c1', 'Wetsuit', '5mm')]);
      final createdAtBefore = (await customFieldRows()).single.createdAt;
      await markEverythingSynced('diveCustomFields');

      await repo.updateDive(
        dive.copyWith(customFields: [field('c1', 'Wetsuit', '7mm', sort: 2)]),
      );

      expect(await tombstonesFor('diveCustomFields'), isEmpty);
      expect(await pendingFor('diveCustomFields'), {'c1'});
      final row = (await customFieldRows()).single;
      expect(row.fieldValue, '7mm');
      expect(row.sortOrder, 2);
      expect(row.createdAt, createdAtBefore);
    });

    test('a removed custom field is deleted and tombstoned', () async {
      final dive = await seed(
        customFields: [
          field('c1', 'Wetsuit', '5mm'),
          field('c2', 'Ferry', 'Ischia'),
        ],
      );
      await markEverythingSynced('diveCustomFields');

      await repo.updateDive(
        dive.copyWith(customFields: [field('c1', 'Wetsuit', '5mm')]),
      );

      expect(await tombstonesFor('diveCustomFields'), ['c2']);
      expect((await customFieldRows()).map((r) => r.id), ['c1']);
      expect(await pendingFor('diveCustomFields'), isEmpty);
    });
  });
}
