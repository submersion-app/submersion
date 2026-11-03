import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _FakeConfirmer implements WriteConfirmer {
  _FakeConfirmer({this.answer = true, this.onAsk});

  final bool answer;
  final Future<void> Function()? onAsk;
  final requests = <WriteConfirmation>[];

  @override
  Future<bool> confirm(WriteConfirmation request) async {
    requests.add(request);
    await onAsk?.call();
    return answer;
  }
}

/// Dives whose delete always fails, to reach the rollback.
class _RefusingCatalog extends WriteCatalog {
  _RefusingCatalog(super.r);

  @override
  List<WritableEntry> get all => [
    for (final entry in super.all)
      if (entry.name == 'buddies') _Refusing(entry) else entry,
  ];

  @override
  WritableEntry? named(String name) {
    for (final entry in all) {
      if (entry.name == name) return entry;
    }
    return null;
  }
}

class _Refusing extends WritableEntry {
  _Refusing(this._inner);

  final WritableEntry _inner;

  @override
  String get name => _inner.name;
  @override
  String get table => _inner.table;
  @override
  Map<String, FieldCodec> get fields => _inner.fields;
  @override
  Map<String, RelationSpec> get relations => _inner.relations;
  @override
  Set<String> get requiredOnCreate => _inner.requiredOnCreate;
  @override
  Future<Set<String>> currentRelation(String id, String relation) =>
      _inner.currentRelation(id, relation);
  @override
  Future<PlanBlock?> refuse(WriteCheck check) => _inner.refuse(check);
  @override
  Future<DeleteReach> deleteReach(String id) => _inner.deleteReach(id);
  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) =>
      _inner.deletedDocumentOwners(id);
  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _inner.create(diverId, values);
  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) =>
      // A real failure in a nested transaction, as a repository would raise.
      DatabaseService.instance.database.transaction(
        () => DatabaseService.instance.database.customStatement(
          'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
          "VALUES ('x', 'no-dive', 'no-tag', 0)",
        ),
      );
  @override
  Future<void> delete(String id, String? ownerId) => _inner.delete(id, ownerId);
}

Matcher _refusedWith(AgentToolErrorCode code) =>
    throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

void main() {
  late AppDatabase db;
  late RecordHarness h;
  late RecordRepositories repositories;
  late WriteCatalog writes;
  late ChangeLogRepository changeLog;
  late List<Set<String>> refreshed;
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
        ),
      );

  Future<void> buddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
        ),
      );

  Future<WritePlan> preview(
    List<Map<String, Object?>> operations, {
    WriteCatalog? catalog,
  }) =>
      WritePlanner(
        writes: catalog ?? writes,
        records: RecordCatalog(repositories),
      ).preview(
        db,
        ChangeSet.parse({'label': 'Fix notes', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
        clientName: 'Test Client',
      );

  Map<String, Object?> note(String id, String text) => {
    'op': 'update',
    'entity': 'dives',
    'id': id,
    'fields': {'notes': text},
  };

  WriteApplier applier({
    WriteConfirmer? confirmer,
    bool confirm = true,
    WriteCatalog? catalog,
    Future<void> Function(Iterable<Document>)? rearm,
  }) => WriteApplier(
    catalog: catalog ?? writes,
    changeLog: changeLog,
    confirmer: confirmer ?? _FakeConfirmer(),
    confirmEnabled: () => confirm,
    afterDiveWrites: (ids) => refreshed.add(ids.toSet()),
    rearmDocuments: rearm ?? (_) async {},
  );

  Future<String?> notes(String id) async =>
      (await h.one('dives', id))?['notes'] as String?;

  Future<List<Map<String, Object?>>> feedRows() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect(
          'SELECT id, source, label, diver_id, event_count '
          'FROM change_log_operations',
        )
        .get();
    return [for (final row in rows) row.data];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = RecordHarness(db);
    await seedTwoDivers(db);
    repositories = RecordRepositories();
    writes = WriteCatalog(repositories);
    changeLog = ChangeLogRepository();
    refreshed = [];
    await dive('d1');
    await dive('d2', owner: kDiverB);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(() => tearDownTestDatabase());

  test('one operation per diver with source agent', () async {
    final plan = await preview([note('d1', 'a'), note('d2', 'b')]);

    final result = await applier().apply(db, plan);

    expect(result.operations, hasLength(2));
    expect(result.operations.map((o) => o.diverId).toSet(), {kDiverA, kDiverB});
    final feed = await feedRows();
    expect(
      feed.map((row) => row['id']).toSet(),
      result.operations.map((o) => o.operationId).toSet(),
    );
    expect(feed.map((row) => row['source']), everyElement('agent'));
    expect(feed.map((row) => row['label']), everyElement('Fix notes'));
    expect(await notes('d1'), 'a');
    expect((await h.one('dives', 'd2', diverId: kDiverB))!['notes'], 'b');
  });

  test('a stale record refuses the whole plan and names it', () async {
    final plan = await preview([note('d1', 'a'), note('d2', 'b')]);
    await (db.update(db.dives)..where((d) => d.id.equals('d2'))).write(
      const DivesCompanion(updatedAt: Value(t + 1)),
    );

    await expectLater(
      applier().apply(db, plan),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.planStale)
            .having((e) => (e.details!['records']! as List).single, 'record', {
              'table': 'dives',
              'id': 'd2',
            }),
      ),
    );
    expect(await notes('d1'), 'seeded');
  });

  test('a deleted record is stale', () async {
    final plan = await preview([note('d1', 'a')]);
    await repositories.dives.deleteDive('d1');

    await expectLater(
      applier().apply(db, plan),
      _refusedWith(AgentToolErrorCode.planStale),
    );
  });

  test('a change to a relation is stale too', () async {
    await buddy('b1');
    await buddy('b2');
    final plan = await preview([
      {
        'op': 'update',
        'entity': 'dives',
        'id': 'd1',
        'relations': {
          'buddies': {
            'add': ['b1'],
          },
        },
      },
    ]);
    final stamp = (await db.select(db.dives).get())
        .firstWhere((d) => d.id == 'd1')
        .updatedAt;
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'link',
            diveId: 'd1',
            buddyId: 'b2',
            createdAt: t,
          ),
        );
    expect(
      (await db.select(db.dives).get())
          .firstWhere((d) => d.id == 'd1')
          .updatedAt,
      stamp,
    );

    await expectLater(
      applier().apply(db, plan),
      _refusedWith(AgentToolErrorCode.planStale),
    );
  });

  test(
    'a record edited while the dialog is open refuses after the confirmation',
    () async {
      final plan = await preview([note('d1', 'agent')]);
      final confirmer = _FakeConfirmer(
        onAsk: () =>
            (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
              const DivesCompanion(
                notes: Value('diver'),
                updatedAt: Value(t + 1),
              ),
            ),
      );

      await expectLater(
        applier(confirmer: confirmer).apply(db, plan),
        _refusedWith(AgentToolErrorCode.planStale),
      );
      expect(await notes('d1'), 'diver');
    },
  );

  test('a database swapped during the wait is refused', () async {
    final plan = await preview([note('d1', 'agent')]);
    final other = createTestDatabase();
    addTearDown(other.close);
    final confirmer = _FakeConfirmer(
      onAsk: () async => DatabaseService.instance.setTestDatabase(other),
    );

    await expectLater(
      applier(confirmer: confirmer).apply(db, plan),
      _refusedWith(AgentToolErrorCode.databaseUnavailable),
    );
    DatabaseService.instance.setTestDatabase(db);
    expect(await notes('d1'), 'seeded');
  });

  test('denied returns not_confirmed and changes nothing', () async {
    final plan = await preview([note('d1', 'agent')]);

    await expectLater(
      applier(confirmer: _FakeConfirmer(answer: false)).apply(db, plan),
      _refusedWith(AgentToolErrorCode.notConfirmed),
    );
    expect(await notes('d1'), 'seeded');
    expect(await feedRows(), isEmpty);
  });

  test('the confirmation carries the client, label and counts', () async {
    final confirmer = _FakeConfirmer();
    final plan = await preview([note('d1', 'a'), note('d2', 'b')]);

    await applier(confirmer: confirmer).apply(db, plan);

    final request = confirmer.requests.single;
    expect(request.clientName, 'Test Client');
    expect(request.label, 'Fix notes');
    expect(request.countsByEntity, {'dives': 2});
    expect(request.countsByDiver, {kDiverA: 1, kDiverB: 1});
    expect(request.items, hasLength(2));
  });

  test('no confirmation is asked when the setting is off', () async {
    final confirmer = _FakeConfirmer(answer: false);
    final plan = await preview([note('d1', 'agent')]);

    await applier(confirmer: confirmer, confirm: false).apply(db, plan);

    expect(confirmer.requests, isEmpty);
    expect(await notes('d1'), 'agent');
  });

  test('a repository refusal rolls back every operation', () async {
    await buddy('b1');
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      note('d1', 'agent'),
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);

    await expectLater(
      applier(catalog: catalog).apply(db, plan),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.writeRefused)
            .having((e) => e.details!['operation'], 'operation', 1)
            .having((e) => e.details!['id'], 'id', 'b1'),
      ),
    );
    expect(await notes('d1'), 'seeded');
    expect(refreshed, isEmpty);
  });

  test('a delete before a refusal comes back with its tanks', () async {
    await buddy('b1');
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank-1', diveId: 'd1'));
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);

    await expectLater(
      applier(catalog: catalog).apply(db, plan),
      _refusedWith(AgentToolErrorCode.writeRefused),
    );

    final doc = await h.one('dives', 'd1', include: ['tanks']);
    expect((doc!['tanks']! as List).single, containsPair('id', 'tank-1'));
  });

  test('a refusal answers without SQL', () async {
    await buddy('b1');
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);

    await expectLater(
      applier(catalog: catalog).apply(db, plan),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.message, 'message', isNot(contains('INSERT')))
            .having((e) => e.message, 'message', isNot(contains('no-tag'))),
      ),
    );
  });

  test('a refused delete arms the reminders it cancelled again', () async {
    await buddy('b1');
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'doc-1',
            diverId: kDiverA,
            diveId: const Value('d1'),
            type: 'other',
            createdAt: t,
            updatedAt: t,
          ),
        );
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);
    final armed = <String>[];

    await expectLater(
      applier(
        catalog: catalog,
        rearm: (documents) async => armed.addAll(documents.map((d) => d.id)),
      ).apply(db, plan),
      _refusedWith(AgentToolErrorCode.writeRefused),
    );

    expect(armed, ['doc-1']);
  });

  test('a refused buddy delete arms their certification documents', () async {
    await buddy('b1');
    await buddy('b2');
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion.insert(
            id: 'c1',
            name: 'Nitrox',
            agency: 'PADI',
            createdAt: t,
            updatedAt: t,
            buddyId: const Value('b2'),
          ),
        );
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'doc-cert',
            diverId: kDiverA,
            certificationId: const Value('c1'),
            type: 'other',
            createdAt: t,
            updatedAt: t,
          ),
        );
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      {'op': 'delete', 'entity': 'buddies', 'id': 'b2'},
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);
    final armed = <String>[];

    await expectLater(
      applier(
        catalog: catalog,
        rearm: (documents) async => armed.addAll(documents.map((d) => d.id)),
      ).apply(db, plan),
      _refusedWith(AgentToolErrorCode.writeRefused),
    );

    expect(armed, ['doc-cert']);
  });

  test('a refused site delete brings its media back', () async {
    await buddy('b1');
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'photo',
            filePath: '/photo.jpg',
            takenAt: const Value(t),
            createdAt: t,
            updatedAt: t,
            siteId: const Value('s1'),
          ),
        );
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      {'op': 'delete', 'entity': 'sites', 'id': 's1'},
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);

    await expectLater(
      applier(catalog: catalog).apply(db, plan),
      _refusedWith(AgentToolErrorCode.writeRefused),
    );

    final kept = await (db.select(
      db.media,
    )..where((m) => m.id.equals('photo'))).getSingleOrNull();
    expect(kept?.siteId, 's1');
  });

  test('a link made to a deleted record after the preview is stale', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    final plan = await preview([
      {'op': 'delete', 'entity': 'sites', 'id': 's1'},
    ]);
    // A dive points at the site now; the site's own row has not changed.
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      const DivesCompanion(siteId: Value('s1')),
    );

    await expectLater(
      applier().apply(db, plan),
      _refusedWith(AgentToolErrorCode.planStale),
    );

    expect(await repositories.sites.getSiteById('s1'), isNotNull);
  });

  test('a site type changed after the preview is stale', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.siteTypes)
        .insert(
          SiteTypesCompanion.insert(
            id: 'kelp',
            name: 'Kelp forest',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.diveTypes)
        .insert(
          DiveTypesCompanion.insert(
            id: 'kelp',
            diverId: const Value(kDiverA),
            name: 'Kelp forest',
            createdAt: t,
            updatedAt: t,
          ),
        );
    final plan = await preview([
      {
        'op': 'update',
        'entity': 'dives',
        'id': 'd1',
        'relations': {
          'site': {
            'set': ['s1'],
          },
        },
      },
    ]);
    expect(plan.items.single.indirectRelations, isEmpty);
    // Site classification links carry no clock on the site's row, so nothing
    // else tells this plan that the dive would now gain a type.
    await db
        .into(db.siteSiteTypes)
        .insert(
          SiteSiteTypesCompanion.insert(
            id: 'st1',
            siteId: 's1',
            siteTypeId: 'kelp',
            createdAt: t,
          ),
        );

    await expectLater(
      applier().apply(db, plan),
      _refusedWith(AgentToolErrorCode.planStale),
    );
  });

  test('the result names the client', () async {
    final plan = await preview([note('d1', 'agent')]);

    final result = await applier().apply(db, plan);

    expect(result.toJson()['client'], 'Test Client');
  });

  test('a refused apply leaves no entry in the feed', () async {
    await buddy('b1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final catalog = _RefusingCatalog(repositories);
    final plan = await preview([
      note('d1', 'agent'),
      {
        'op': 'update',
        'entity': 'buddies',
        'id': 'b1',
        'fields': {'notes': 'x'},
      },
    ], catalog: catalog);

    await expectLater(
      applier(catalog: catalog).apply(db, plan),
      _refusedWith(AgentToolErrorCode.writeRefused),
    );

    await changeLog.settleAll();
    final feed = await changeLog.getFeed(
      diverId: kDiverA,
      filter: const ChangeLogFilter(),
    );
    expect(feed, isEmpty);
  });

  test('records are stamped pending', () async {
    final plan = await preview([note('d1', 'agent')]);

    await applier().apply(db, plan);

    final pending = await (db.select(
      db.syncRecords,
    )..where((r) => r.recordId.equals('d1'))).get();
    expect(pending.map((r) => r.syncStatus), contains('pending'));
  });

  test('the refresh runs for the changed and created dives', () async {
    final plan = await preview([
      note('d1', 'agent'),
      {
        'op': 'create',
        'entity': 'dives',
        'fields': {'date_time': '2025-01-02T08:00:00Z'},
      },
      {'op': 'delete', 'entity': 'dives', 'id': 'd2'},
    ]);

    final result = await applier().apply(db, plan);

    expect(refreshed.single, {'d1', result.created.single.id});
  });

  test('created records are reported with their ids', () async {
    final plan = await preview([
      {
        'op': 'create',
        'entity': 'buddies',
        'fields': {'name': 'Rui'},
      },
    ]);

    final result = await applier().apply(db, plan);

    final created = result.created.single;
    expect(created.entity, 'buddies');
    expect(created.operation, 0);
    expect((await h.one('buddies', created.id))!['name'], 'Rui');
    expect(result.toJson()['created'], [
      {'operation': 0, 'entity': 'buddies', 'id': created.id},
    ]);
  });

  test('a delete and an update land in one operation', () async {
    await buddy('b1');
    final plan = await preview([
      note('d1', 'agent'),
      {'op': 'delete', 'entity': 'buddies', 'id': 'b1'},
    ]);

    final result = await applier().apply(db, plan);

    expect(result.operations, hasLength(1));
    expect(await h.one('buddies', 'b1'), isNull);
    expect(await notes('d1'), 'agent');
  });

  test('a diver save during the wait is not filed under the agent', () async {
    await buddy('b1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final plan = await preview([note('d1', 'agent')]);
    final confirmer = _FakeConfirmer(
      onAsk: () => repositories.buddies.setFavorite('b1', true),
    );

    final result = await applier(confirmer: confirmer).apply(db, plan);

    final feed = await feedRows();
    final agent = feed.where((row) => row['source'] == 'agent');
    expect(agent.map((row) => row['id']), [
      result.operations.single.operationId,
    ]);
    expect(
      feed.where((row) => row['source'] == ChangeLogSource.manual.name),
      isNotEmpty,
    );
  });
}
