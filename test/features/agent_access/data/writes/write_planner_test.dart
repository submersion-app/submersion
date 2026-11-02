import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../records/record_harness.dart';

class _ReadOnlyStamper extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}

/// Counts what reaches the engine, as the spec's preview test asks.
class _Counter extends QueryInterceptor {
  int transactions = 0;
  int writes = 0;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    transactions++;
    return super.beginTransaction(parent);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes++;
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes++;
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes++;
    return super.runDelete(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late _Counter counter;
  late WritePlanner planner;
  const t = kSeedTime;

  Future<void> dive(String id, {String owner = kDiverA}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: 1710408600000,
          createdAt: t,
          updatedAt: t,
          notes: const Value('seeded'),
          waterTemp: const Value(12.0),
          boatName: const Value('Sea Star'),
        ),
      );

  Future<void> buddy(String id, {String owner = kDiverA}) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
        ),
      );

  Future<void> tag(String id, {String owner = kDiverA}) => db
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

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      planner.preview(
        db,
        ChangeSet.parse({'label': 'Tidy', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
        clientName: 'test',
      );

  Map<String, Object?> update(
    String entity,
    String id, {
    Map<String, Object?>? fields,
    Map<String, Object?>? relations,
  }) => {
    'op': 'update',
    'entity': entity,
    'id': id,
    'fields': ?fields,
    'relations': ?relations,
  };

  setUp(() async {
    counter = _Counter();
    db = AppDatabase(
      NativeDatabase.memory(
        setup: registerAppSqlFunctions,
      ).interceptWith(counter),
    );
    DatabaseService.instance.setTestDatabase(db);
    await seedTwoDivers(db);
    final repositories = RecordRepositories();
    planner = WritePlanner(
      writes: WriteCatalog(repositories),
      records: RecordCatalog(repositories),
    );
    await dive('d1');
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  test('the counter sees a transaction and a write', () async {
    counter
      ..transactions = 0
      ..writes = 0;

    await db.transaction(() => dive('counted'));

    expect(counter.transactions, 1);
    expect(counter.writes, greaterThan(0));
  });

  test('a preview opens no transaction and ticks no table', () async {
    await buddy('b1');
    final ticks = <Set<TableUpdate>>[];
    final sub = db.tableUpdates().listen(ticks.add);
    counter
      ..transactions = 0
      ..writes = 0;

    await preview([
      {
        'op': 'create',
        'entity': 'buddies',
        'fields': {'name': 'New'},
      },
      update(
        'dives',
        'd1',
        fields: {'water_temp_c': 24.5},
        relations: {
          'buddies': {
            'add': ['b1'],
          },
        },
      ),
      {'op': 'delete', 'entity': 'buddies', 'id': 'b1'},
    ]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(counter.transactions, 0);
    expect(counter.writes, 0);
    expect(ticks, isEmpty);
  });

  test('each changed field shows old and new', () async {
    final plan = await preview([
      update('dives', 'd1', fields: {'water_temp_c': 24.5}),
    ]);

    final item = plan.items.single;
    expect(item.kind, ChangeKind.update);
    expect(item.diverId, kDiverA);
    expect(item.fields['water_temp_c']!.oldValue, 12.0);
    expect(item.fields['water_temp_c']!.newValue, 24.5);
    expect(plan.applicable, isTrue);
  });

  test('an unchanged value is not listed', () async {
    final plan = await preview([
      update(
        'dives',
        'd1',
        fields: {'water_temp_c': 12, 'boat_name': 'Marlin'},
      ),
    ]);

    expect(plan.items.single.fields.keys, ['boat_name']);
  });

  test(
    'a record with nothing left to change is reported, not planned',
    () async {
      final plan = await preview([
        update('dives', 'd1', fields: {'water_temp_c': 12}),
      ]);

      expect(plan.items, isEmpty);
      expect(plan.unchanged.single.id, 'd1');
      expect(plan.applicable, isFalse);
    },
  );

  test('null is listed as a clear and an omitted key is not', () async {
    final plan = await preview([
      update('dives', 'd1', fields: {'boat_name': null}),
    ]);

    final item = plan.items.single;
    expect(item.fields.keys, ['boat_name']);
    expect(item.fields['boat_name']!.oldValue, 'Sea Star');
    expect(item.fields['boat_name']!.newValue, isNull);
    expect(item.values.containsKey('boat_name'), isTrue);
  });

  test('null on a required field is blocked', () async {
    final plan = await preview([
      update('dives', 'd1', fields: {'notes': null}),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    expect(plan.items.single.block?.detail, contains('notes'));
    expect(plan.applicable, isFalse);
  });

  test('a missing record is blocked', () async {
    final plan = await preview([
      update('dives', 'nope', fields: {'notes': 'x'}),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.recordNotFound);
  });

  test('an entity that cannot be changed yet is blocked', () async {
    final plan = await preview([
      update('trips', 'tr1', fields: {'name': 'x'}),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.notWritable);
    expect(plan.items.single.block?.detail, contains('dives'));
  });

  test('an unknown field is blocked and lists the names', () async {
    final plan = await preview([
      update('buddies', 'd1', fields: {'nickname': 'x'}),
    ]);
    expect(plan.items.single.block?.reason, BlockReason.recordNotFound);

    await buddy('b1');
    final known = await preview([
      update('buddies', 'b1', fields: {'nickname': 'x'}),
    ]);
    expect(known.items.single.block?.reason, BlockReason.unknownField);
    expect(known.items.single.block?.detail, contains('social_handle'));
  });

  test('a create must carry its required fields', () async {
    final plan = await preview([
      {
        'op': 'create',
        'entity': 'dives',
        'fields': {'notes': 'x'},
      },
    ]);

    expect(plan.items.single.block?.reason, BlockReason.missingField);
    expect(plan.items.single.block?.detail, contains('date_time'));
  });

  test('a create lists its values as new and owns the named diver', () async {
    final plan = await preview([
      {
        'op': 'create',
        'entity': 'buddies',
        'diver_id': kDiverB,
        'fields': {'name': 'Rui'},
      },
    ]);

    final item = plan.items.single;
    expect(item.id, isNull);
    expect(item.diverId, kDiverB);
    expect(item.fields['name']!.newValue, 'Rui');
    expect(item.values['name'], 'Rui');
  });

  test('a relation add and remove are compared with the links', () async {
    await buddy('b1');
    await buddy('b2');
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'link',
            diveId: 'd1',
            buddyId: 'b1',
            role: const Value('buddy'),
            createdAt: t,
          ),
        );

    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'buddies': {
            'add': ['b1', 'b2'],
            'remove': ['b9'],
          },
        },
      ),
    ]);

    final delta = plan.items.single.relations['buddies']!;
    expect(delta.add, {'b2'});
    expect(delta.remove, isEmpty);
  });

  test('set replaces tags', () async {
    await tag('t1');
    await tag('t2');
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion.insert(
            id: 'link',
            diveId: 'd1',
            tagId: 't1',
            createdAt: t,
          ),
        );

    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'tags': {
            'set': ['t2'],
          },
        },
      ),
    ]);

    final delta = plan.items.single.relations['tags']!;
    expect(delta.add, {'t2'});
    expect(delta.remove, {'t1'});
  });

  test('a single relation takes one id', () async {
    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'site': {
            'set': ['s1', 's2'],
          },
        },
      ),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.invalidValue);
  });

  test('a buddy of another profile is blocked', () async {
    await buddy('b-other', owner: kDiverB);

    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'buddies': {
            'add': ['b-other'],
          },
        },
      ),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.otherProfileReference);
  });

  test('an unknown reference is blocked', () async {
    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'tags': {
            'add': ['nope'],
          },
        },
      ),
    ]);

    expect(plan.items.single.block?.reason, BlockReason.unknownReference);
  });

  test('a record twice is blocked', () async {
    final plan = await preview([
      update('dives', 'd1', fields: {'notes': 'one'}),
      update('dives', 'd1', fields: {'boat_name': 'two'}),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block?.reason, BlockReason.duplicateRecord);
  });

  test('a reference to a record the set deletes is blocked', () async {
    await buddy('b1');

    final plan = await preview([
      update(
        'dives',
        'd1',
        relations: {
          'buddies': {
            'add': ['b1'],
          },
        },
      ),
      {'op': 'delete', 'entity': 'buddies', 'id': 'b1'},
    ]);

    expect(plan.items[0].block?.reason, BlockReason.referenceDeleted);
  });

  test('a library site the owner may not edit is blocked', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            sharedLibraryId: const Value('lib-1'),
          ),
        );
    final repositories = RecordRepositories();
    final refusing = WritePlanner(
      writes: WriteCatalog(repositories, stamper: _ReadOnlyStamper()),
      records: RecordCatalog(repositories),
    );

    final plan = await refusing.preview(
      db,
      ChangeSet.parse({
        'label': 'Tidy',
        'operations': [
          update('sites', 's1', fields: {'name': 'Renamed'}),
        ],
      }),
      resolveDiver: (id) async => id ?? kDiverA,
    );

    expect(plan.items.single.block?.reason, BlockReason.notPermitted);
  });

  test('a delete names the record', () async {
    final plan = await preview([
      {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
    ]);

    final item = plan.items.single;
    expect(item.kind, ChangeKind.delete);
    expect(item.id, 'd1');
    expect(item.diverId, kDiverA);
    expect(plan.applicable, isTrue);
  });

  test('counts are per entity and per diver across two profiles', () async {
    await dive('d2', owner: kDiverB);
    await buddy('b1');

    final plan = await preview([
      update('dives', 'd1', fields: {'notes': 'a'}),
      update('dives', 'd2', fields: {'notes': 'b'}),
      update('buddies', 'b1', fields: {'notes': 'c'}),
    ]);

    expect(plan.countsByEntity, {'dives': 2, 'buddies': 1});
    expect(plan.countsByDiver, {kDiverA: 2, kDiverB: 1});
  });

  test('the plan marks each record with its version and links', () async {
    await tag('t1');

    final plan = await preview([
      update(
        'dives',
        'd1',
        fields: {'notes': 'x'},
        relations: {
          'tags': {
            'add': ['t1'],
          },
        },
      ),
    ]);

    final marker = plan.markers.single;
    expect(marker.table, 'dives');
    expect(marker.id, 'd1');
    expect(marker.updatedAt, t);
    expect(marker.relations['tags'], isEmpty);
  });

  test('a blocked plan has no plan_id', () async {
    final plan = await preview([
      update('dives', 'nope', fields: {'notes': 'x'}),
    ]);

    final json = plan.toJson();
    expect(json['applicable'], isFalse);
    expect(json.containsKey('plan_id'), isFalse);
    expect(json.containsKey('expires_at'), isFalse);
  });

  test('an applicable plan has an id and an expiry and encodes', () async {
    final plan = await preview([
      update('dives', 'd1', fields: {'notes': 'x'}),
    ]);

    final json = plan.toJson();
    expect(json['plan_id'], plan.id);
    expect(json['expires_at'], isNotNull);
    expectWireResult(json);
  });
}
