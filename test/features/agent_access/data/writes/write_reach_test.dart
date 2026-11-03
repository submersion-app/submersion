import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

/// A delete lists everything it takes and everything it unlinks, and the
/// schema says what that is, so a table added later is counted too.
void main() {
  late AppDatabase db;
  late RecordRepositories repositories;
  const t = kSeedTime;

  Future<void> dive(String id, {String? site}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value(kDiverA),
          diveDateTime: 1710408600000,
          createdAt: t,
          updatedAt: t,
          siteId: Value(site),
        ),
      );

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
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

  Future<void> certification(String id, {String? owner, String? instructor}) =>
      db
          .into(db.certifications)
          .insert(
            CertificationsCompanion.insert(
              id: id,
              name: id,
              agency: 'PADI',
              createdAt: t,
              updatedAt: t,
              buddyId: Value(owner),
              instructorId: Value(instructor),
            ),
          );

  Future<void> document(
    String id, {
    String? diveId,
    String? siteId,
    String? buddyId,
    String? certificationId,
  }) => db
      .into(db.documents)
      .insert(
        DocumentsCompanion.insert(
          id: id,
          diverId: kDiverA,
          diveId: Value(diveId),
          siteId: Value(siteId),
          buddyId: Value(buddyId),
          certificationId: Value(certificationId),
          type: 'other',
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> media(String id, {String? diveId, String? siteId}) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          filePath: '/$id.jpg',
          takenAt: const Value(t),
          createdAt: t,
          updatedAt: t,
          diveId: Value(diveId),
          siteId: Value(siteId),
        ),
      );

  Future<void> tank(String id, String diveId) => db
      .into(db.diveTanks)
      .insert(DiveTanksCompanion.insert(id: id, diveId: diveId));

  Future<void> plan(String id, {String? siteId, String? linkedDive}) => db
      .into(db.divePlans)
      .insert(
        DivePlansCompanion.insert(
          id: id,
          name: id,
          gfLow: const Value(30),
          gfHigh: const Value(70),
          createdAt: t,
          updatedAt: t,
          siteId: Value(siteId),
          linkedDiveId: Value(linkedDive),
        ),
      );

  Future<WritePlan> previewDelete(String entity, String id) =>
      WritePlanner(
        writes: WriteCatalog(repositories),
        records: RecordCatalog(repositories),
      ).preview(
        db,
        ChangeSet.parse({
          'label': 'Tidy',
          'operations': [
            {'op': 'delete', 'entity': entity, 'id': id},
          ],
        }),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  Map<String, Object?> reachOf(WritePlan plan) =>
      plan.items.single.toJson()['also_reaches']! as Map<String, Object?>;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedTwoDivers(db);
    repositories = RecordRepositories();
  });

  tearDown(() => tearDownTestDatabase());

  group('countCascaded', () {
    test('follows the schema down through a child', () async {
      await buddy('b1');
      await certification('c1', owner: 'b1');
      await db
          .into(db.certificationCurrencyPrefs)
          .insert(
            CertificationCurrencyPrefsCompanion.insert(
              id: 'p1',
              certificationId: 'c1',
              ruleId: 'r1',
              createdAt: t,
              updatedAt: t,
            ),
          );

      final counts = await countCascaded('buddies', 'b1');

      expect(counts['certifications'], 1);
      expect(counts['certification_currency_prefs'], 1);
    });

    test('leaves out a table with no rows and an excepted one', () async {
      await dive('d1');
      await tank('t1', 'd1');
      await db
          .into(db.diveWeights)
          .insert(
            DiveWeightsCompanion.insert(
              id: 'w1',
              diveId: 'd1',
              weightType: 'belt',
              amountKg: 4,
              createdAt: t,
            ),
          );

      final counts = await countCascaded(
        'dives',
        'd1',
        except: {'dive_weights'},
      );

      expect(counts, {'dive_tanks': 1});
    });

    test('counts only the record it was asked about', () async {
      await dive('d1');
      await dive('d2');
      await tank('t1', 'd2');

      expect(await countCascaded('dives', 'd1'), isEmpty);
    });
  });

  group('countUnlinked', () {
    test('counts what a foreign key clears', () async {
      await buddy('b1');
      await certification('c1', instructor: 'b1');

      expect(await countUnlinked('buddies', 'b1'), {'certifications': 1});
    });

    test('counts a row once when two of its links name the record', () async {
      await dive('d1');
      await plan('p1', linkedDive: 'd1');
      await db.customStatement(
        "UPDATE dive_plans SET source_dive_id = 'd1' WHERE id = 'p1'",
      );

      expect(await countUnlinked('dives', 'd1'), {'dive_plans': 1});
    });
  });

  test('a dive lists its own rows, its media and what it unlinks', () async {
    await site('s1');
    await dive('d1');
    await tank('t1', 'd1');
    await document('doc1', diveId: 'd1');
    await media('only', diveId: 'd1');
    await media('kept', diveId: 'd1', siteId: 's1');
    await plan('p1', linkedDive: 'd1');

    final plan_ = await previewDelete('dives', 'd1');

    final reach = plan_.items.single.reach;
    expect(reach.records, {'documents': 1, 'media': 1});
    expect(reach.parts, containsPair('dive_tanks', 1));
    expect(reach.unlinked, {'dive_plans': 1, 'media': 1});
    expect(
      reachOf(plan_)['deleted_records'],
      allOf(containsPair('documents', 1), containsPair('dive_tanks', 1)),
    );
    expect(reachOf(plan_)['unlinked_records'], containsPair('dive_plans', 1));
  });

  test('a site lists its children, its media and its plans', () async {
    await site('s1');
    await dive('d1', site: 's1');
    await document('doc1', siteId: 's1');
    await media('only', siteId: 's1');
    await media('kept', siteId: 's1', diveId: 'd1');
    await plan('p1', siteId: 's1');
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f1',
            siteId: 's1',
            type: 'mooring',
            latitude: 12.1,
            longitude: -68.2,
            createdAt: t,
            updatedAt: t,
          ),
        );

    final reach = (await previewDelete('sites', 's1')).items.single.reach;

    expect(reach.linkedDives, {kDiverA: 1});
    expect(reach.records, {'documents': 1, 'media': 1});
    expect(reach.parts, {'site_features': 1});
    expect(reach.unlinked, {'dive_plans': 1, 'media': 1});
  });

  test('a buddy counts the documents of their certifications', () async {
    await buddy('b1');
    await certification('c1', owner: 'b1');
    await document('doc1', buddyId: 'b1');
    await document('doc2', certificationId: 'c1');

    final reach = (await previewDelete('buddies', 'b1')).items.single.reach;

    expect(reach.records, {'certifications': 1, 'documents': 2});
    expect(reach.parts, isEmpty);
  });

  test('a buddy links count once, as linked dives', () async {
    await buddy('b1');
    await dive('d1');
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'l1',
            diveId: 'd1',
            buddyId: 'b1',
            createdAt: t,
          ),
        );

    final reach = (await previewDelete('buddies', 'b1')).items.single.reach;

    expect(reach.linkedDives, {kDiverA: 1});
    expect(reach.parts, isEmpty);
  });
}
