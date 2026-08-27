import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/core/constants/enums.dart'
    show TankMaterial, TankRole, WeightType;
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart'
    show TankSpecField;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id, {String notes = ''}) => repository.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: notes),
  );

  group('bulkUpdateFields', () {
    test(
      'writes only the given columns, bumps updatedAt, skips other dives',
      () async {
        await seed('d1', notes: 'keep');
        await seed('d2', notes: 'keep2');
        await seed('d3', notes: 'untouched');

        await repository.bulkUpdateFields([
          'd1',
          'd2',
        ], const DivesCompanion(rating: Value(5), waterType: Value('salt')));

        final r1 = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('d1'))).getSingle();
        final r3 = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('d3'))).getSingle();
        expect(r1.rating, 5);
        expect(r1.waterType, 'salt');
        expect(r1.notes, 'keep'); // untouched column preserved
        expect(r3.rating, isNull); // dive outside the id list untouched
        expect(r3.waterType, isNull);
      },
    );

    test('is a no-op for an empty id list', () async {
      await repository.bulkUpdateFields(
        const [],
        const DivesCompanion(rating: Value(3)),
      );
    });

    test('with an empty companion is a no-op (no updatedAt touch)', () async {
      await seed('x');
      await (db.update(db.dives)..where((t) => t.id.equals('x'))).write(
        const DivesCompanion(updatedAt: Value(123)),
      );
      await repository.bulkUpdateFields(['x'], const DivesCompanion());
      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('x'))).getSingle();
      expect(row.updatedAt, 123); // unchanged — no sync-visible touch
    });
  });

  group('bulkAppendNotes', () {
    test('appends to existing notes and to empty notes', () async {
      await seed('a', notes: 'Cozumel');
      await seed('b', notes: '');

      await repository.bulkAppendNotes(['a', 'b'], '\nGreat viz');

      final ra = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('a'))).getSingle();
      final rb = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('b'))).getSingle();
      expect(ra.notes, 'Cozumel\nGreat viz');
      expect(rb.notes, '\nGreat viz');
    });
  });

  group('bulkReplaceTags', () {
    setUp(() async {
      await db.customStatement(
        'PRAGMA foreign_keys = OFF',
      ); // test-only isolation
    });

    test('replaces existing tag membership with the given set', () async {
      await seed('d1');
      await repository.bulkAddTags(['d1'], ['old-tag']);

      await repository.bulkReplaceTags(['d1'], ['t1', 't2']);

      final rows = await (db.select(
        db.diveTags,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.tagId).toSet(), {'t1', 't2'});
    });
  });

  group('bulk equipment', () {
    setUp(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
    });

    test('add then remove adjusts membership; replace overwrites', () async {
      await seed('d1');
      await repository.bulkAddEquipment(['d1'], ['e1', 'e2']);
      var rows = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e1', 'e2'});

      await repository.bulkRemoveEquipment(['d1'], ['e1']);
      rows = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e2'});

      await repository.bulkReplaceEquipment(['d1'], ['e9']);
      rows = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e9'});
    });

    test(
      'add merges with pre-existing gear on each dive, never wipes',
      () async {
        // Reproduces the r/submersion report: d1 has e1, d2 has e2.
        await seed('d1');
        await seed('d2');
        await repository.bulkAddEquipment(['d1'], ['e1']);
        await repository.bulkAddEquipment(['d2'], ['e2']);

        // Bulk-add e3 to BOTH dives; existing gear must survive.
        await repository.bulkAddEquipment(['d1', 'd2'], ['e3']);

        final d1 = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals('d1'))).get();
        final d2 = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals('d2'))).get();
        expect(d1.map((r) => r.equipmentId).toSet(), {'e1', 'e3'});
        expect(d2.map((r) => r.equipmentId).toSet(), {'e2', 'e3'});
      },
    );
  });

  group('membership counts', () {
    setUp(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
    });

    test('equipmentCountsForDives returns per-item dive counts', () async {
      await repository.bulkAddEquipment(['d1', 'd2'], ['shared']); // both
      await repository.bulkAddEquipment(['d1'], ['onlyD1']); // one
      final counts = await repository.equipmentCountsForDives(['d1', 'd2']);
      expect(counts['shared'], 2);
      expect(counts['onlyD1'], 1);
      expect(counts.containsKey('missing'), isFalse);
      expect(await repository.equipmentCountsForDives(const []), isEmpty);
    });

    test('tagCountsForDives returns per-tag dive counts', () async {
      await repository.bulkAddTags(['d1', 'd2'], ['shared']);
      await repository.bulkAddTags(['d1'], ['onlyD1']);
      final counts = await repository.tagCountsForDives(['d1', 'd2']);
      expect(counts['shared'], 2);
      expect(counts['onlyD1'], 1);
    });

    test('diveTypeCountsForDives returns per-type dive counts', () async {
      await repository.bulkAddDiveTypes(['d1', 'd2'], ['shared']);
      await repository.bulkAddDiveTypes(['d1'], ['onlyD1']);
      final counts = await repository.diveTypeCountsForDives(['d1', 'd2']);
      expect(counts['shared'], 2);
      expect(counts['onlyD1'], 1);
    });
  });

  group('bulk tanks', () {
    const al80 = domain.DiveTank(
      id: '',
      name: 'AL80',
      volume: 11.1,
      gasMix: domain.GasMix(o2: 21, he: 0),
    );

    test(
      'bulkAddTank appends; onlyIfEmpty skips dives that already have a tank',
      () async {
        await seed('empty');
        await seed('hasTank');
        await repository.bulkAddTank(['hasTank'], al80);

        await repository.bulkAddTank(
          ['empty', 'hasTank'],
          al80,
          onlyIfEmpty: true,
        );

        final emptyTanks = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals('empty'))).get();
        final hasTankTanks = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals('hasTank'))).get();
        expect(emptyTanks.length, 1);
        expect(emptyTanks.single.tankName, 'AL80');
        expect(emptyTanks.single.tankOrder, 0);
        expect(hasTankTanks.length, 1); // skipped — still just the original
      },
    );

    test('bulkReplaceTanks overwrites the whole list', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], al80);
      await repository.bulkReplaceTanks(
        ['d1'],
        const [
          domain.DiveTank(
            id: '',
            name: 'D12',
            volume: 24,
            gasMix: domain.GasMix(o2: 32),
          ),
        ],
      );
      final rows = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.tankName, 'D12');
      expect(rows.single.o2Percent, 32);
    });

    test(
      'bulkAddTanks with onlyIfEmpty adds ALL tanks to an empty dive',
      () async {
        await seed('e');
        await repository.bulkAddTanks(
          ['e'],
          const [al80, al80],
          onlyIfEmpty: true,
        );
        final rows = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals('e'))).get();
        expect(rows.length, 2); // both tanks added, not just the first
      },
    );
  });

  group('bulkUpdateTankSpecs', () {
    // A tank as MacDive imports it: pressures present, everything that
    // identifies the cylinder missing (#797).
    const imported = domain.DiveTank(
      id: '',
      startPressure: 200,
      endPressure: 50,
      gasMix: domain.GasMix(o2: 21),
    );

    const al80 = domain.DiveTank(
      id: '',
      name: 'Primary',
      volume: 11.1,
      workingPressure: 207,
      material: TankMaterial.aluminum,
      role: TankRole.stage,
      presetName: 'al80',
      gasMix: domain.GasMix(o2: 32),
    );

    test('writes gated fields and leaves start/end pressure alone', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], imported);

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        al80,
        const {
          TankSpecField.preset,
          TankSpecField.volume,
          TankSpecField.workingPressure,
          TankSpecField.material,
          TankSpecField.role,
        },
      );

      final row = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).getSingle();
      expect(row.presetName, 'al80');
      expect(row.volume, 11.1);
      expect(row.workingPressure, 207);
      expect(row.tankMaterial, 'aluminum');
      expect(row.tankRole, 'stage');
      // The whole point of #797: pressure data survives.
      expect(row.startPressure, 200);
      expect(row.endPressure, 50);
    });

    test('leaves ungated fields untouched', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], imported);

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        al80,
        const {TankSpecField.volume},
      );

      final row = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).getSingle();
      expect(row.volume, 11.1);
      expect(row.presetName, isNull);
      expect(row.workingPressure, isNull);
      expect(row.tankMaterial, isNull);
      expect(row.tankName, isNull);
      expect(row.tankRole, 'backGas'); // the imported tank's default
      expect(row.o2Percent, 21); // gas mix was not gated on
    });

    test('gasMix gates both o2 and he together', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], imported);

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        const domain.DiveTank(id: '', gasMix: domain.GasMix(o2: 18, he: 45)),
        const {TankSpecField.gasMix},
      );

      final row = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).getSingle();
      expect(row.o2Percent, 18);
      expect(row.hePercent, 45);
    });

    test('updates every tank on a dive, preserving row id and order', () async {
      await seed('d1');
      await repository.bulkAddTanks(['d1'], const [imported, imported]);
      final before =
          await (db.select(db.diveTanks)
                ..where((t) => t.diveId.equals('d1'))
                ..orderBy([(t) => OrderingTerm(expression: t.tankOrder)]))
              .get();

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        al80,
        const {TankSpecField.volume},
      );

      final after =
          await (db.select(db.diveTanks)
                ..where((t) => t.diveId.equals('d1'))
                ..orderBy([(t) => OrderingTerm(expression: t.tankOrder)]))
              .get();
      expect(after.map((r) => r.id), before.map((r) => r.id));
      expect(after.map((r) => r.tankOrder), [0, 1]);
      expect(after.every((r) => r.volume == 11.1), isTrue);
    });

    test('skips dives with no tanks and returns the touched count', () async {
      await seed('hasTank');
      await seed('tankless');
      await repository.bulkAddTank(['hasTank'], imported);

      final touched = await repository.bulkUpdateTankSpecs(
        ['hasTank', 'tankless'],
        al80,
        const {TankSpecField.volume},
      );

      expect(touched, 1);
      final rows = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('tankless'))).get();
      expect(rows, isEmpty); // no tank conjured up for a tankless dive
    });

    test('is a no-op when no fields are gated on', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], imported);
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        const DivesCompanion(updatedAt: Value(123)),
      );

      final touched = await repository.bulkUpdateTankSpecs(
        ['d1'],
        al80,
        const {},
      );

      expect(touched, 0);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('d1'))).getSingle();
      expect(dive.updatedAt, 123); // no sync-visible touch
    });
  });

  group('divesWithoutTanksCount', () {
    test('counts only the selected dives that have no tank rows', () async {
      await seed('hasOne');
      await seed('hasTwo');
      await seed('tankless');
      await seed('outsideSelection');
      const bare = domain.DiveTank(id: '');
      await repository.bulkAddTank(['hasOne'], bare);
      await repository.bulkAddTanks(['hasTwo'], const [bare, bare]);

      expect(
        await repository.divesWithoutTanksCount([
          'hasOne',
          'hasTwo',
          'tankless',
        ]),
        1, // outsideSelection is tankless too, but was not selected
      );
      expect(await repository.divesWithoutTanksCount(const []), 0);
    });
  });

  group('bulkRestoreTankRows', () {
    test('writes prior column values back onto the same row ids', () async {
      await seed('d1');
      await repository.bulkAddTank(
        ['d1'],
        const domain.DiveTank(
          id: '',
          volume: 11.1,
          startPressure: 200,
          endPressure: 50,
        ),
      );
      final prior = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).get();

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        const domain.DiveTank(id: '', volume: 24),
        const {TankSpecField.volume},
      );
      await repository.bulkRestoreTankRows(prior);

      final after = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).getSingle();
      expect(after.id, prior.single.id); // same row, not a re-insert
      expect(after.volume, 11.1);
      expect(after.startPressure, 200);
    });

    test('restores a column that the update had set from null', () async {
      await seed('d1');
      await repository.bulkAddTank([
        'd1',
      ], const domain.DiveTank(id: '', startPressure: 200));
      final prior = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(prior.single.volume, isNull);

      await repository.bulkUpdateTankSpecs(
        ['d1'],
        const domain.DiveTank(id: '', volume: 24),
        const {TankSpecField.volume},
      );
      await repository.bulkRestoreTankRows(prior);

      final after = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('d1'))).getSingle();
      expect(after.volume, isNull); // prior NULL restored, not left at 24
    });
  });

  group('bulk weights', () {
    const belt = domain.DiveWeight(
      id: '',
      diveId: '',
      weightType: WeightType.belt,
      amountKg: 4,
    );

    test('add appends; replace overwrites', () async {
      await seed('d1');
      await repository.bulkAddWeights(['d1'], [belt]);
      var rows = await (db.select(
        db.diveWeights,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.amountKg, 4);

      await repository.bulkReplaceWeights(
        ['d1'],
        const [
          domain.DiveWeight(
            id: '',
            diveId: '',
            weightType: WeightType.integrated,
            amountKg: 6,
          ),
        ],
      );
      rows = await (db.select(
        db.diveWeights,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.amountKg, 6);
    });
  });
}
