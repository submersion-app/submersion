import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(String id, {String? diveId, String? siteId}) => MediaItem(
    id: id,
    diveId: diveId,
    siteId: siteId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test('unlinkFromDive clears the FK and keeps the row', () async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    await repo.unlinkFromDive(['m1']);

    final m = await repo.getMediaById('m1');
    expect(m, isNotNull);
    expect(m!.diveId, isNull);
    expect(m.retainInLibrary, isFalse, reason: 'nothing latches the flag');
  });

  test('unlinkFromSite clears only the site link', () async {
    await insertDive('d1');
    await insertSite('s1');
    await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));

    await repo.unlinkFromSite(['m1']);

    final m = await repo.getMediaById('m1');
    expect(m!.siteId, isNull);
    expect(m.diveId, 'd1');
    expect(m.retainInLibrary, isFalse);
  });

  test(
    'partitionForSiteUnlink keeps dive-linked rows, deletes the rest',
    () async {
      await insertDive('d1');
      await insertSite('s1');
      await repo.createMedia(item('both', diveId: 'd1', siteId: 's1'));
      await repo.createMedia(item('site-only', siteId: 's1'));

      final split = await repo.partitionForSiteUnlink(['both', 'site-only']);

      expect(split.diveLinked, ['both']);
      expect(split.deletable, ['site-only']);
    },
  );

  test('partitionForSiteUnlink short-circuits an empty list', () async {
    final split = await repo.partitionForSiteUnlink(const []);
    expect(split.diveLinked, isEmpty);
    expect(split.deletable, isEmpty);
  });

  test('empty id lists are no-ops', () async {
    await repo.unlinkFromDive(const []);
    await repo.unlinkFromSite(const []);
  });

  test(
    'getSweepableOrphanIds ignores a legacy retain_in_library flag',
    () async {
      await repo.createMedia(item('sweep-me'));
      await repo.createMedia(item('legacy-kept'));
      // A row a pre-upgrade build latched: the flag no longer protects it.
      await db.customStatement(
        'UPDATE media SET retain_in_library = 1, created_at = 0 WHERE id = ?',
        ['legacy-kept'],
      );
      await db.customStatement('UPDATE media SET created_at = 0 WHERE id = ?', [
        'sweep-me',
      ]);

      final ids = await repo.getSweepableOrphanIds(
        olderThan: DateTime(2026, 1, 1),
      );
      expect(ids.toSet(), {'sweep-me', 'legacy-kept'});
    },
  );
}
