import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

/// What a plan says is what a write does: nothing an update reaches, directly
/// or through a repository's own rules, goes unlisted.
void main() {
  late AppDatabase db;
  late RecordHarness h;
  late RecordRepositories repositories;
  late WriteCatalog writes;
  const t = kSeedTime;

  Future<void> dive(
    String id, {
    String owner = kDiverA,
    String? water,
    String? entry,
    String? site,
    double? visibilityM,
    int? entryTime,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: 1710408600000,
          createdAt: t,
          updatedAt: t,
          waterType: Value(water),
          entryMethod: Value(entry),
          siteId: Value(site),
          visibilityMeters: Value(visibilityM),
          entryTime: Value(entryTime),
        ),
      );

  Future<void> site(
    String id, {
    String owner = kDiverA,
    String? water,
    String? library,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: 'Site $id',
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
          waterType: Value(water),
          sharedLibraryId: Value(library),
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

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      WritePlanner(
        writes: writes,
        records: RecordCatalog(repositories),
      ).preview(
        db,
        ChangeSet.parse({'label': 'Tidy', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  Future<WriteResult> apply(WritePlan plan) => WriteApplier(
    catalog: writes,
    changeLog: ChangeLogRepository(),
    confirmer: _Allow(),
    confirmEnabled: () => false,
    afterDiveWrites: (_) {},
  ).apply(db, plan);

  Map<String, Object?> linkSite(String id, String siteId, [Map? fields]) => {
    'op': 'update',
    'entity': 'dives',
    'id': id,
    'fields': ?fields,
    'relations': {
      'site': {
        'set': [siteId],
      },
    },
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = RecordHarness(db);
    await seedTwoDivers(db);
    repositories = RecordRepositories();
    writes = WriteCatalog(repositories);
  });

  tearDown(() => tearDownTestDatabase());

  group('a site link', () {
    test('lists the water type it snaps on', () async {
      await dive('d1', water: 'fresh');
      await site('s1', water: 'salt');

      final plan = await preview([linkSite('d1', 's1')]);

      final change = plan.items.single.fields['water_type']!;
      expect(change.oldValue, 'fresh');
      expect(change.newValue, 'salt');
    });

    test('keeps a value the change set names, even an unchanged one', () async {
      await dive('d1', water: 'salt');
      await site('s1', water: 'fresh');

      final plan = await preview([
        linkSite('d1', 's1', {'water_type': 'salt'}),
      ]);
      expect(plan.items.single.fields.containsKey('water_type'), isFalse);

      await apply(plan);

      expect((await h.one('dives', 'd1'))!['water_type'], 'salt');
    });

    test('writes what it listed', () async {
      await dive('d1', water: 'fresh');
      await site('s1', water: 'salt');

      await apply(await preview([linkSite('d1', 's1')]));

      expect((await h.one('dives', 'd1'))!['water_type'], 'salt');
    });
  });

  group('visibility', () {
    test('setting a band clears the measurement, and says so', () async {
      await dive('d1', visibilityM: 12);

      final plan = await preview([
        {
          'op': 'update',
          'entity': 'dives',
          'id': 'd1',
          'fields': {'visibility': 'good'},
        },
      ]);
      expect(plan.items.single.fields['visibility_m']!.oldValue, 12.0);
      expect(plan.items.single.fields['visibility_m']!.newValue, isNull);

      await apply(plan);

      final doc = (await h.one('dives', 'd1'))!;
      expect(doc['visibility'], 'good');
      expect(doc['visibility_m'], isNull);
    });

    Future<WritePlan> restate(String band) => preview([
      {
        'op': 'update',
        'entity': 'dives',
        'id': 'd1',
        'fields': {'visibility': band},
      },
    ]);

    test('the band it already holds still clears a measurement', () async {
      await dive('d1', visibilityM: 12);
      await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
        const DivesCompanion(visibility: Value('good')),
      );

      final plan = await restate('good');

      expect(plan.unchanged, isEmpty);
      expect(plan.items.single.fields.keys, ['visibility_m']);
      expect(plan.items.single.fields['visibility_m']!.indirect, isTrue);

      await apply(plan);

      final doc = (await h.one('dives', 'd1'))!;
      expect(doc['visibility'], 'good');
      expect(doc['visibility_m'], isNull);
    });

    test('the band it already holds changes nothing on its own', () async {
      await dive('d1');
      await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
        const DivesCompanion(visibility: Value('good')),
      );

      final plan = await restate('good');

      expect(plan.items, isEmpty);
      expect(plan.unchanged.single.id, 'd1');
    });
  });

  test('moving a dive lists the entry time that moves with it', () async {
    await dive('d1', entryTime: 1710408600000);

    final plan = await preview([
      {
        'op': 'update',
        'entity': 'dives',
        'id': 'd1',
        'fields': {'date_time': '2024-03-14T11:30:00Z'},
      },
    ]);

    final change = plan.items.single.fields['entry_time']!;
    expect(change.oldValue, '2024-03-14T09:30:00.000Z');
    expect(change.newValue, '2024-03-14T11:30:00.000Z');
  });

  test('a deleted reference makes the plan stale', () async {
    await dive('d1');
    await buddy('b1');
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
    await repositories.buddies.deleteBuddy('b1');

    await expectLater(
      apply(plan),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planStale,
        ),
      ),
    );
  });

  test('deleting a library site is blocked for an editor too', () async {
    await site('s1', library: 'lib-1');

    final plan = await preview([
      {'op': 'delete', 'entity': 'sites', 'id': 's1'},
    ]);

    expect(plan.items.single.block?.reason, BlockReason.notPermitted);
    expect(plan.items.single.block?.detail, contains('library'));
  });

  test('a library editor can change a site through apply', () async {
    await site('s1', library: 'lib-1');
    expect(await LibraryEditStamper().mayEdit('s1'), isTrue);

    await apply(
      await preview([
        {
          'op': 'update',
          'entity': 'sites',
          'id': 's1',
          'fields': {'name': 'Renamed'},
        },
      ]),
    );

    expect((await h.one('sites', 's1'))!['name'], 'Renamed');
  });
}
