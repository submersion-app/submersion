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
    // A URL row is dive-only too now: no source type is exempt from the
    // cascade, so it dies with its dive like any other photo.
    final url = await repo.createMedia(
      item('c.jpg', diveId: 'd1', sourceType: MediaSourceType.networkUrl),
    );
    await repo.createMedia(item('other.jpg', siteId: 's1')); // unrelated row

    final split = await repo.partitionMediaForDiveDeletion(['d1']);
    expect(split.doomed.map((m) => m.id).toSet(), {doomed.id, url.id});
    expect(split.doomed.firstWhere((m) => m.id == doomed.id).contentHash, 'h1');
    expect(split.unlinkIds, [siteLinked.id]);
  });

  test(
    'partitionMediaForDiveDeletion short-circuits an empty dive list',
    () async {
      // Bulk callers hand over collections that can be empty (consolidation's
      // secondary-dive set, an empty multi-select), and must get empty buckets
      // rather than every unlinked row in the library.
      await insertDive('d1');
      await insertSite('s1');
      await repo.createMedia(item('a.jpg', diveId: 'd1'));
      await repo.createMedia(item('site-only.jpg', siteId: 's1'));

      final split = await repo.partitionMediaForDiveDeletion([]);

      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, isEmpty);
    },
  );

  test('unlinkMediaFromDeletedDives nulls diveId and keeps the row', () async {
    await insertDive('d1');
    final m = await repo.createMedia(item('a.jpg', diveId: 'd1'));
    await repo.unlinkMediaFromDeletedDives([m.id]);
    final got = await repo.getMediaById(m.id);
    expect(got, isNotNull);
    expect(got!.diveId, isNull);
  });

  test('getSweepableOrphanIds honours linkage and age only', () async {
    await insertDive('d1');
    final orphan = await repo.createMedia(item('old.jpg'));
    // Network rows used to be exempt as "library-level" media. Every row
    // now needs a dive or site, so an unlinked network row is a sweepable
    // orphan like any other.
    final manifestOrphan = await repo.createMedia(
      item('manifest.jpg', sourceType: MediaSourceType.manifestEntry),
    );
    final urlOrphan = await repo.createMedia(
      item('url.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    // createMedia stamps createdAt with the current wall clock, so a future
    // cutoff includes the fixtures and a past cutoff excludes them.
    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));

    final sweepable = await repo.getSweepableOrphanIds(olderThan: future);
    expect(sweepable.toSet(), {orphan.id, manifestOrphan.id, urlOrphan.id});
    expect(sweepable, isNot(contains(linked.id)));

    expect(await repo.getSweepableOrphanIds(olderThan: past), isEmpty);
  });

  test('getAllContentHashes collects distinct non-null hashes', () async {
    await insertDive('d1');
    await repo.createMedia(item('a.jpg', diveId: 'd1', hash: 'h1'));
    await repo.createMedia(item('b.jpg', diveId: 'd1', hash: 'h1')); // dup
    await repo.createMedia(item('c.jpg', diveId: 'd1', hash: 'h2'));
    await repo.createMedia(item('d.jpg', diveId: 'd1')); // no hash
    expect(await repo.getAllContentHashes(), {'h1', 'h2'});
  });

  test('getRemoteStampedSummaries reports per-tier stamps', () async {
    await insertDive('d1');
    final orig = await repo.createMedia(
      item('a.jpg', diveId: 'd1', hash: 'h1'),
    );
    await repo.stampRemoteUploaded(orig.id, uploadedAt: DateTime(2026, 2));
    final thumbed = await repo.createMedia(
      item('b.jpg', diveId: 'd1', hash: 'h2'),
    );
    await repo.stampRemoteThumbUploaded(
      thumbed.id,
      uploadedAt: DateTime(2026, 2),
    );
    await repo.createMedia(item('c.jpg', diveId: 'd1', hash: 'h3')); // none

    final summaries = await repo.getRemoteStampedSummaries();
    expect(summaries, hasLength(2));
    final byId = {for (final s in summaries) s.id: s};
    expect(byId[orig.id]!.contentHash, 'h1');
    expect(byId[orig.id]!.hasOriginal, isTrue);
    expect(byId[orig.id]!.hasThumb, isFalse);
    expect(byId[orig.id]!.hasRendition, isFalse);
    expect(byId[thumbed.id]!.hasThumb, isTrue);
    expect(byId[thumbed.id]!.hasOriginal, isFalse);
  });

  test('clearRemoteThumbUploaded nulls only the thumb stamp', () async {
    await insertDive('d1');
    final m = await repo.createMedia(item('a.jpg', diveId: 'd1', hash: 'h1'));
    await repo.stampRemoteUploaded(m.id, uploadedAt: DateTime(2026, 2));
    await repo.stampRemoteThumbUploaded(m.id, uploadedAt: DateTime(2026, 2));
    await repo.clearRemoteThumbUploaded(m.id);
    final got = await repo.getMediaById(m.id);
    expect(got!.remoteThumbUploadedAt, isNull);
    expect(got.remoteUploadedAt, isNotNull);
  });
}
