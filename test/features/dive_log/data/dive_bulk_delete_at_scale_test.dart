import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../helpers/test_database.dart';

/// The bundled SQLite binds at most 32766 variables per statement, so a bulk
/// delete that puts every selected id into one `IN (...)` fails once "select
/// all" on a large logbook passes that many dives (issue #1953). Every step
/// of the delete has to chunk: the media partition and unlink, the plan
/// links, the route lookup, the dive rows and the tombstones.
void main() {
  // One past the bound-variable ceiling.
  const count = 33000;
  const epoch = 1000;

  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaRepository mediaRepository;
  late DiveRepository diveRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    mediaRepository = MediaRepository();
    diveRepository = DiveRepository(
      mediaRepository: mediaRepository,
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: mediaRepository,
        queue: () => MediaTransferQueueRepository(database: cacheDb),
      ),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  List<String> diveIds(int n) => [for (var i = 0; i < n; i++) 'dive-$i'];

  Future<void> insertDives(List<String> ids) => db.batch((b) {
    b.insertAll(db.dives, [
      for (final (i, id) in ids.indexed)
        DivesCompanion.insert(
          id: id,
          diveDateTime: epoch + i,
          createdAt: epoch,
          updatedAt: epoch,
        ),
    ]);
  });

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(epoch),
          updatedAt: const Value(epoch),
        ),
      );

  MediaItem photo(String name, {required String diveId, String? siteId}) =>
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        filePath: '/photos/$name',
        localPath: '/photos/$name',
        originalFilename: name,
        diveId: diveId,
        siteId: siteId,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<int> countRows(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  test('bulkDeleteDives deletes more dives than one statement can bind, '
      'with one tombstone per dive', () async {
    final ids = diveIds(count);
    await insertDives(ids);
    await insertSite('site-1');
    // Dive-only media dies with its dive; site-linked media survives with
    // the dive link cleared. Both steps bind the dying dives' ids.
    final doomed = await mediaRepository.createMedia(
      photo('doomed.jpg', diveId: ids.first),
    );
    final kept = await mediaRepository.createMedia(
      photo('kept.jpg', diveId: ids.last, siteId: 'site-1'),
    );
    // A plan linked to a dive has its link cleared before the delete.
    await DivePlanRepository().savePlan(
      DivePlan(
        id: 'plan-1',
        name: 'plan-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        gfLow: 30,
        gfHigh: 70,
        linkedDiveId: ids[count ~/ 2],
      ),
    );

    final deleted = await diveRepository.bulkDeleteDives(ids);

    expect(deleted, ids);
    expect(await countRows('dives'), 0);
    expect(await mediaRepository.getMediaById(doomed.id), isNull);
    final survivor = await mediaRepository.getMediaById(kept.id);
    expect(survivor, isNotNull);
    expect(survivor!.diveId, isNull);
    expect(survivor.siteId, 'site-1');
    final plan = await db
        .customSelect(
          "SELECT linked_dive_id FROM dive_plans WHERE id = 'plan-1'",
        )
        .getSingle();
    expect(plan.readNullable<String>('linked_dive_id'), isNull);

    final tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('dives'))).get();
    expect(tombstones.map((t) => t.recordId).toSet(), ids.toSet());
    expect(
      tombstones.map((t) => t.hlc).toSet(),
      hasLength(count),
      reason: 'each dive delete is its own event, with its own clock',
    );
    for (final t in tombstones) {
      expect(t.originHlc, t.hlc, reason: 'a local delete is its own origin');
    }
  });

  test('getDivesByIds reads more ids than one statement can bind, '
      'newest first', () async {
    // Only a few of the ids exist: every id is still bound, and mapping a
    // full dive per row is not what this test is about.
    await insertDives(['old', 'mid', 'new']);
    final ids = [...diveIds(count), 'mid', 'old', 'new'];

    final dives = await diveRepository.getDivesByIds(ids);

    expect(dives.map((d) => d.id), ['new', 'mid', 'old']);
  });

  test('getDivesByIds breaks a time tie by dive number, highest first and '
      'unnumbered last', () async {
    // The sort moved from SQL to Dart with chunking, so it has to keep
    // SQLite's `dive_number DESC` order, which puts NULL last. Inserted
    // and requested in the reverse of that order, so only the tie-break
    // can produce it.
    await db.batch((b) {
      b.insertAll(db.dives, [
        for (final (id, number) in [
          ('unnumbered', null),
          ('one', 1),
          ('two', 2),
        ])
          DivesCompanion.insert(
            id: id,
            diveNumber: Value(number),
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
      ]);
    });

    final dives = await diveRepository.getDivesByIds([
      'unnumbered',
      'one',
      'two',
    ]);

    expect(dives.map((d) => d.id), ['two', 'one', 'unnumbered']);
  });
}
