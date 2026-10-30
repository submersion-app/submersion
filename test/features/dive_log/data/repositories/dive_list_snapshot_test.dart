import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_list_snapshot.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    repository = DiveRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<void> insertDive(String id, {required int at}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('diver'),
          diveDateTime: at,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertTank(String id, String diveId) => db
      .into(db.diveTanks)
      .insert(DiveTanksCompanion.insert(id: id, diveId: diveId));

  Future<void> seed() async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver',
            name: 'D',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await insertDive('old', at: 1000);
    await insertDive('new', at: 2000);
    await insertTank('old-tank', 'old');
  }

  Future<List<String>> statementsOf(Future<void> Function() body) async {
    final logged = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    // A long statement reaches the zone as several print calls.
    return logged.join().split('Drift: Sent').skip(1).toList();
  }

  group('getDiveListSnapshot', () {
    test('with nothing to reuse, loads what getAllDives loads', () async {
      await seed();

      final snapshot = await repository.getDiveListSnapshot(diverId: 'diver');

      expect(snapshot.dives, await repository.getAllDives(diverId: 'diver'));
    });

    test('an unchanged list returns the same snapshot from one read', () async {
      await seed();
      final first = await repository.getDiveListSnapshot(diverId: 'diver');

      late DiveListSnapshot second;
      final statements = await statementsOf(() async {
        second = await repository.getDiveListSnapshot(
          diverId: 'diver',
          previous: first,
        );
      });

      expect(second, same(first));
      expect(statements, hasLength(1));
    });

    test('hydrates only the changed dive and reuses the others', () async {
      await seed();
      final first = await repository.getDiveListSnapshot(diverId: 'diver');
      final untouched = first.dives.firstWhere((d) => d.id == 'old');

      await (db.update(db.dives)..where((t) => t.id.equals('new'))).write(
        const DivesCompanion(notes: Value('edited'), updatedAt: Value(5)),
      );
      late DiveListSnapshot second;
      final statements = await statementsOf(() async {
        second = await repository.getDiveListSnapshot(
          diverId: 'diver',
          previous: first,
        );
      });

      expect(second.dives.map((d) => d.id), ['new', 'old']);
      expect(second.dives.first.notes, 'edited');
      expect(second.dives.last, same(untouched));
      expect(statements.where((s) => s.contains('"dive_tanks"')), hasLength(1));
      expect(
        statements.singleWhere((s) => s.contains('"dive_tanks"')),
        isNot(contains(RegExp(r'\bold\b'))),
      );
    });

    // A trip assignment, a reparse and the dive-type mirror all write the row
    // without touching updated_at, so a diff keyed on that column misses them.
    test('sees a write that leaves updated_at alone', () async {
      await seed();
      final first = await repository.getDiveListSnapshot(diverId: 'diver');

      await db.customUpdate(
        "UPDATE dives SET notes = 'unstamped' WHERE id = 'old'",
        updates: {db.dives},
      );
      final second = await repository.getDiveListSnapshot(
        diverId: 'diver',
        previous: first,
      );

      expect(second, isNot(same(first)));
      expect(second.dives.firstWhere((d) => d.id == 'old').notes, 'unstamped');
    });

    test('drops a deleted dive and adds a new one', () async {
      await seed();
      final first = await repository.getDiveListSnapshot(diverId: 'diver');

      await (db.delete(db.dives)..where((t) => t.id.equals('old'))).go();
      await insertDive('newest', at: 3000);
      final second = await repository.getDiveListSnapshot(
        diverId: 'diver',
        previous: first,
      );

      expect(second.dives.map((d) => d.id), ['newest', 'new']);
    });

    test('follows a date edit to its new place in the list', () async {
      await seed();
      final first = await repository.getDiveListSnapshot(diverId: 'diver');

      await (db.update(db.dives)..where((t) => t.id.equals('old'))).write(
        const DivesCompanion(diveDateTime: Value(3000)),
      );
      final second = await repository.getDiveListSnapshot(
        diverId: 'diver',
        previous: first,
      );

      expect(second.dives.map((d) => d.id), ['old', 'new']);
      expect(second.dives, await repository.getAllDives(diverId: 'diver'));
    });

    test('keeps to the diver it is asked about', () async {
      await seed();
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'other',
              name: 'O',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'theirs',
              diverId: const Value('other'),
              diveDateTime: 4000,
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      final mine = await repository.getDiveListSnapshot(diverId: 'diver');
      final everyone = await repository.getDiveListSnapshot();

      expect(mine.dives.map((d) => d.id), ['new', 'old']);
      expect(everyone.dives.map((d) => d.id), ['theirs', 'new', 'old']);
    });
  });

  // Readers share the list, so a reorder must not move a dive to another id.
  test('advancing pairs a held dive with its own row', () async {
    await seed();
    final first = await repository.getDiveListSnapshot(diverId: 'diver');
    first.dives.sort((a, b) => b.id.compareTo(a.id));
    expect(first.dives.map((d) => d.id), ['old', 'new']);

    final advanced = first.advancedTo(first.rows);

    expect(advanced.rows.map((r) => r.id), advanced.dives.map((d) => d.id));
  });

  group('watchDiveHydrationWrites', () {
    // The incremental refresh reuses a held dive unless its own row changed,
    // and the fallback for everything else a dive embeds is this tick. A table
    // the hydration reads and this set misses goes stale on screen.
    test('covers every table a hydrated dive reads', () async {
      await seed();
      await _linkEveryRelation(db);

      final statements = await statementsOf(() async {
        await repository.getAllDives(diverId: 'diver');
      });
      final read = <String>{
        for (final statement in statements)
          for (final match in RegExp(
            r'(?:FROM|JOIN)\s+"?([a-z_]+)"?',
          ).allMatches(statement))
            match.group(1)!,
      };

      expect(read, {'dives', ...DiveRepository.diveHydrationTables});
    });

    test('fires on a child write without a debounce', () async {
      await seed();
      final ticks = <void>[];
      final subscription = repository.watchDiveHydrationWrites().listen(
        ticks.add,
      );
      addTearDown(subscription.cancel);

      await insertTank('second-tank', 'new');
      await pumpEventQueue();

      expect(ticks, hasLength(1));
    });

    test('stays quiet on a dives write', () async {
      await seed();
      final ticks = <void>[];
      final subscription = repository.watchDiveHydrationWrites().listen(
        ticks.add,
      );
      addTearDown(subscription.cancel);

      await insertDive('newest', at: 3000);
      await pumpEventQueue();

      expect(ticks, isEmpty);
    });
  });
}

/// Links dive `new` to one row of each relation a hydrated dive embeds, so
/// every batched read in the hydration runs.
Future<void> _linkEveryRelation(AppDatabase db) async {
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: 'site',
          name: 'Site',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion.insert(
          id: 'center',
          name: 'Center',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: 'trip',
          name: 'Trip',
          startDate: 0,
          endDate: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await (db.update(db.dives)..where((t) => t.id.equals('new'))).write(
    const DivesCompanion(
      siteId: Value('site'),
      diveCenterId: Value('center'),
      tripId: Value('trip'),
    ),
  );
  await db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: 'gear',
          name: 'Gear',
          type: 'other',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: 'new', equipmentId: 'gear'),
      );
}
