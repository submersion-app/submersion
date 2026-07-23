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

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

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
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(
    String name, {
    String? diveId,
    String? siteId,
    String? hash,
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: sourceType,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    siteId: siteId,
    contentHash: hash,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('partitionMediaForDiveDeletion splits doomed from unlink', () async {
    await insertDive('d1');
    await insertSite('s1');
    final doomed = await repo.createMedia(
      item('a.jpg', diveId: 'd1', hash: 'h1'), // dive-only gallery photo
    );
    final siteLinked = await repo.createMedia(
      item('b.jpg', diveId: 'd1', siteId: 's1'),
    );
    final library = await repo.createMedia(
      item('c.jpg', diveId: 'd1', sourceType: MediaSourceType.networkUrl),
    );
    await repo.createMedia(item('other.jpg')); // unrelated row

    final split = await repo.partitionMediaForDiveDeletion(['d1']);
    expect(split.doomed.map((m) => m.id), [doomed.id]);
    expect(split.doomed.single.contentHash, 'h1');
    expect(split.unlinkIds.toSet(), {siteLinked.id, library.id});
  });

  test('unlinkMediaFromDeletedDives nulls diveId and keeps the row', () async {
    await insertDive('d1');
    final m = await repo.createMedia(item('a.jpg', diveId: 'd1'));
    await repo.unlinkMediaFromDeletedDives([m.id]);
    final got = await repo.getMediaById(m.id);
    expect(got, isNotNull);
    expect(got!.diveId, isNull);
  });

  test('getSweepableOrphanIds honours linkage, source type, and age', () async {
    await insertDive('d1');
    final orphan = await repo.createMedia(item('old.jpg'));
    final libraryOrphan = await repo.createMedia(
      item('lib.jpg', sourceType: MediaSourceType.manifestEntry),
    );
    final manifestOrphan = await repo.createMedia(
      item('url.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    // createMedia stamps createdAt with the current wall clock, so a future
    // cutoff includes the fixtures and a past cutoff excludes them.
    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));

    final sweepable = await repo.getSweepableOrphanIds(olderThan: future);
    expect(sweepable, [orphan.id]);
    expect(sweepable, isNot(contains(libraryOrphan.id)));
    expect(sweepable, isNot(contains(manifestOrphan.id)));
    expect(sweepable, isNot(contains(linked.id)));

    expect(await repo.getSweepableOrphanIds(olderThan: past), isEmpty);
  });
}
