import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
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

    test('add merges with pre-existing gear on each dive, never wipes', () async {
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
