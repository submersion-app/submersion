import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// The bulk edit Site row (issue #3657): each selected dive gets what picking
/// the site on that one dive gives it, so the site's water type, entry/exit
/// methods and dive types snap on per dive, and the rows the diver set in the
/// same edit win over them.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late BulkDiveEditService service;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> insertDive(
    String id, {
    String? siteId,
    String? waterType,
    String? entryMethod,
    String? exitMethod,
    String? boatName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            siteId: Value(siteId),
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            exitMethod: Value(exitMethod),
            boatName: Value(boatName),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSite(
    String id, {
    String? waterType,
    String? entryMethod,
    String? exitMethod,
    List<String> siteTypeIds = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            exitMethod: Value(exitMethod),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final typeId in siteTypeIds) {
      await db
          .into(db.siteSiteTypes)
          .insert(
            SiteSiteTypesCompanion(
              id: Value('$id-$typeId'),
              siteId: Value(id),
              siteTypeId: Value(typeId),
              createdAt: Value(now),
            ),
          );
    }
  }

  Future<Dive> row(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<List<String>> typesOf(String id) async =>
      (await diveRepo.getDiveById(id))!.diveTypeIds.toList()..sort();

  test('links every dive and snaps the site onto each one', () async {
    await insertDive('d1', waterType: 'fresh');
    await insertDive('d2', entryMethod: 'boat', exitMethod: 'ladder');
    await insertSite(
      's1',
      waterType: 'salt',
      entryMethod: 'shore',
      siteTypeIds: ['wreck'],
    );

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1', 'd2'],
        ops: [SiteOp(siteId: 's1')],
      ),
    );

    final d1 = await row('d1');
    expect(d1.siteId, 's1');
    expect(d1.waterType, 'salt');
    expect(d1.entryMethod, 'shore');
    expect(d1.exitMethod, 'shore');
    final d2 = await row('d2');
    expect(d2.siteId, 's1');
    expect(d2.waterType, 'salt');
    expect(d2.entryMethod, 'shore');
    // d2's exit was set apart from its entry by hand, so it stays.
    expect(d2.exitMethod, 'ladder');
    expect(await typesOf('d1'), containsAll(['recreational', 'wreck']));
    expect(await typesOf('d2'), containsAll(['recreational', 'wreck']));
  });

  test('a manual exit override on one dive survives', () async {
    await insertDive('d1', entryMethod: 'boat', exitMethod: 'backRoll');
    await insertSite('s1', entryMethod: 'shore');

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [SiteOp(siteId: 's1')],
      ),
    );

    final d1 = await row('d1');
    expect(d1.entryMethod, 'shore');
    expect(d1.exitMethod, 'backRoll');
  });

  test('rows set in the same edit win over the site values', () async {
    await insertDive('d1');
    await insertSite('s1', waterType: 'salt', entryMethod: 'shore');

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        scalars: DivesCompanion(
          waterType: Value('fresh'),
          entryMethod: Value('boat'),
        ),
        ops: [SiteOp(siteId: 's1')],
      ),
    );

    final d1 = await row('d1');
    expect(d1.siteId, 's1');
    expect(d1.waterType, 'fresh');
    expect(d1.entryMethod, 'boat');
  });

  test('a dive type removed in the same edit stays removed', () async {
    await insertDive('d1');
    await insertSite('s1', siteTypeIds: ['wreck']);

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [
          SiteOp(siteId: 's1'),
          DiveTypesOp(mode: BulkCollectionMode.remove, diveTypeIds: ['wreck']),
        ],
      ),
    );

    expect(await typesOf('d1'), ['recreational']);
  });

  test('an empty site unlinks every dive and keeps its values', () async {
    await insertSite('s1', waterType: 'salt', entryMethod: 'shore');
    await insertDive(
      'd1',
      siteId: 's1',
      waterType: 'salt',
      entryMethod: 'shore',
      exitMethod: 'shore',
    );
    await insertDive('d2', siteId: 's1');

    await service.apply(
      const BulkEditRequest(diveIds: ['d1', 'd2'], ops: [SiteOp(siteId: null)]),
    );

    final d1 = await row('d1');
    expect(d1.siteId, isNull);
    expect(d1.waterType, 'salt');
    expect(d1.entryMethod, 'shore');
    expect(d1.exitMethod, 'shore');
    expect((await row('d2')).siteId, isNull);
  });

  test('leaves the columns the site does not touch alone', () async {
    await insertDive('d1', boatName: 'Aurora');
    await insertSite('s1', waterType: 'salt');

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [SiteOp(siteId: 's1')],
      ),
    );

    expect((await row('d1')).boatName, 'Aurora');
  });

  test('marks every dive pending for sync', () async {
    await insertDive('d1');
    await insertDive('d2');
    await insertSite('s1');
    await db.delete(db.syncRecords).go();

    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1', 'd2'],
        ops: [SiteOp(siteId: 's1')],
      ),
    );

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals('dives'))).get();
    expect(pending.map((r) => r.recordId), containsAll(['d1', 'd2']));
  });

  test(
    'undo restores the site, the snapped values and the dive types',
    () async {
      await insertSite('old');
      await insertSite(
        's1',
        waterType: 'salt',
        entryMethod: 'shore',
        siteTypeIds: ['wreck'],
      );
      await insertDive('d1', siteId: 'old', waterType: 'fresh');

      final snapshot = await service.apply(
        const BulkEditRequest(
          diveIds: ['d1'],
          ops: [SiteOp(siteId: 's1')],
        ),
      );
      expect(await typesOf('d1'), containsAll(['recreational', 'wreck']));

      await service.undo(snapshot);

      final d1 = await row('d1');
      expect(d1.siteId, 'old');
      expect(d1.waterType, 'fresh');
      expect(d1.entryMethod, isNull);
      expect(d1.exitMethod, isNull);
      expect(await typesOf('d1'), ['recreational']);
    },
  );
}
