import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';

RecordEntity<String> _entity({
  String table = 'tags',
  RecordScope? scope,
  String? parentColumn,
  String orderBy = 'r0.id',
  Map<String, BlockLoader<String>> blocks = const {},
}) => RecordEntity<String>(
  name: 'things',
  table: table,
  scope: scope ?? owned(),
  parentColumn: parentColumn,
  orderBy: orderBy,
  load: (ids, _) async => {
    for (final id in ids)
      if (id != 'gone') id: id,
  },
  document: (s) => {'id': s, 'name': 'name of $s', 'body': 'long'},
  summaryKeys: const ['name'],
  blocks: blocks,
);

void main() {
  late AppDatabase db;
  const a = 'diver-a';
  const b = 'diver-b';
  const t = 1700000000000;
  const load = RecordLoad(include: {}, diverId: a);

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in [a, b]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner) in [('t3', a), ('t1', a), ('t2', a), ('x1', b)]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip',
            name: 'trip',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
            diverId: const Value(a),
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip2',
            name: 'trip2',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
            diverId: const Value(a),
          ),
        );
    for (final (id, trip) in [('c1', 'trip'), ('c2', 'trip2')]) {
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: id,
              tripId: trip,
              label: Value(id),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });

  tearDown(() => db.close());

  group('visibleIds', () {
    test('visibleIds keeps only what the diver may see', () async {
      final reader = RecordReader(db);
      expect(await reader.visibleIds(_entity(), ['t1', 'x1', 'nope'], a), [
        't1',
      ]);
    });

    test('visibleIds preserves the order asked for', () async {
      final reader = RecordReader(db);
      expect(await reader.visibleIds(_entity(), ['t3', 't1', 't2'], a), [
        't3',
        't1',
        't2',
      ]);
    });

    test('an entity with no scope sees every row', () async {
      final reader = RecordReader(db);
      expect(
        await reader.visibleIds(_entity(scope: everyone()), ['x1', 't1'], a),
        ['x1', 't1'],
      );
    });

    test('an empty list asks nothing', () async {
      expect(
        await RecordReader(db).visibleIds(_entity(), const [], a),
        isEmpty,
      );
    });
  });

  group('page', () {
    test('page counts everything and returns one window', () async {
      final page = await RecordReader(
        db,
      ).page(_entity(), a, limit: 2, offset: 1);
      expect(page.total, 3);
      expect(page.ids, ['t2', 't3']);
    });

    test('page uses the entity order, with the id as the tie break', () async {
      final page = await RecordReader(
        db,
      ).page(_entity(orderBy: 'r0.name DESC'), a, limit: 10, offset: 0);
      expect(page.ids, ['t3', 't2', 't1']);
    });

    test('page filters by parent id', () async {
      final entity = _entity(
        table: 'trip_cylinders',
        scope: everyone(),
        parentColumn: 'trip_id',
      );
      final page = await RecordReader(
        db,
      ).page(entity, a, parentId: 'trip2', limit: 10, offset: 0);
      expect(page.total, 1);
      expect(page.ids, ['c2']);
    });

    test('page refuses a parent id on an entity without a parent', () {
      expect(
        () => RecordReader(
          db,
        ).page(_entity(), a, parentId: 'p', limit: 10, offset: 0),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.code,
            'code',
            AgentToolErrorCode.invalidArgument,
          ),
        ),
      );
    });
  });

  group('RecordEntity', () {
    test(
      'read keys documents by id and drops an id that did not load',
      () async {
        final docs = await _entity().read(['t1', 'gone'], load);
        expect(docs.keys, ['t1']);
        expect(docs['t1']!['name'], 'name of t1');
      },
    );

    test('read runs only the blocks asked for', () async {
      final entity = _entity(
        blocks: {
          'one': (s, _) async => 'first $s',
          'two': (s, _) async => 'second $s',
        },
      );
      final docs = await entity.read([
        't1',
      ], const RecordLoad(include: {'two'}, diverId: a));
      expect(docs['t1']!['two'], 'second t1');
      expect(docs['t1']!.containsKey('one'), isFalse);
    });

    test('blocks lists the block names', () {
      final entity = _entity(blocks: {'one': (s, _) async => s});
      expect(entity.blocks, {'one'});
    });

    test('summaries project the keys plus the id, in id order', () async {
      final rows = await _entity().summaries(['t2', 't1'], load);
      expect(rows, [
        {'id': 't2', 'name': 'name of t2'},
        {'id': 't1', 'name': 'name of t1'},
      ]);
    });

    test('a summarize function replaces the projection', () async {
      final entity = RecordEntity<String>(
        name: 'things',
        table: 'tags',
        scope: owned(),
        load: (ids, _) async => {for (final id in ids) id: id},
        document: (s) => {'id': s},
        summaryKeys: const [],
        summarize: (ids, _) async => [
          for (final id in ids) {'custom': id},
        ],
      );
      expect(await entity.summaries(['a'], load), [
        {'custom': 'a'},
      ]);
    });
  });

  group('loaders', () {
    test('loadEach skips a null', () async {
      final loaded = await loadEach<String>([
        'a',
        'b',
      ], (id) async => id == 'a' ? 'found' : null);
      expect(loaded, {'a': 'found'});
    });

    test('byId keys a list', () {
      expect(byId(['aa', 'bbb'], (s) => s.length.toString()), {
        '2': 'aa',
        '3': 'bbb',
      });
    });

    test('loadChildren finds each row through its parent', () async {
      final calls = <List<String>>[];
      final loaded = await loadChildren<String>(
        db,
        table: 'trip_cylinders',
        parentColumn: 'trip_id',
        ids: ['c2', 'c1', 'nope'],
        idOf: (s) => s,
        byParents: (parents) async {
          calls.add(parents);
          return {
            'trip': ['c1', 'unasked'],
            'trip2': ['c2'],
          };
        },
      );
      expect(calls.single.toSet(), {'trip', 'trip2'});
      expect(loaded, {'c1': 'c1', 'c2': 'c2'});
    });
  });
}
