import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Queries behind the one-time origin republish: which rows this device
/// imported still carry a store stamp (peers may have dropped it), and which
/// of its own rows carry the "missing" flag (a peer may have put it there).
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<MediaItem> row(
    String name, {
    String? origin,
    MediaSourceType sourceType = MediaSourceType.localFile,
    bool stamped = false,
    bool thumbOnly = false,
    bool flagged = false,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: sourceType,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        diveId: 'd1',
        originDeviceId: origin,
        contentHash: stamped || thumbOnly ? 'hash-$name' : null,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (stamped) {
      await repo.stampRemoteUploaded(created.id, uploadedAt: DateTime(2026, 2));
    }
    if (thumbOnly) {
      await repo.stampRemoteThumbUploaded(
        created.id,
        uploadedAt: DateTime(2026, 2),
      );
    }
    if (flagged) await repo.markAsOrphaned(created.id);
    return created;
  }

  test('stamped ids are scoped to rows this device imported', () async {
    final mine = await row('mine.jpg', origin: 'me', stamped: true);
    final mineThumb = await row('thumb.jpg', origin: 'me', thumbOnly: true);
    await row('unstamped.jpg', origin: 'me');
    await row('theirs.jpg', origin: 'other', stamped: true);
    // Gallery rows carry no origin: device-portable, nothing to republish.
    await row(
      'gallery.jpg',
      sourceType: MediaSourceType.platformGallery,
      stamped: true,
    );

    final ids = await repo.getStoreStampedMediaIdsOwnedBy('me');

    expect(ids.toSet(), {mine.id, mineThumb.id});
  });

  test('flagged rows are scoped to rows this device imported', () async {
    final mine = await row('mine.jpg', origin: 'me', flagged: true);
    await row('fine.jpg', origin: 'me');
    await row('theirs.jpg', origin: 'other', flagged: true);

    final flagged = await repo.getOrphanedMediaOwnedBy('me');

    expect(flagged.map((m) => m.id), [mine.id]);
    expect(flagged.single.isOrphaned, isTrue);
  });

  test('republishing marks the rows pending without touching them', () async {
    final a = await row('a.jpg', origin: 'me', stamped: true);
    final b = await row('b.jpg', origin: 'me', stamped: true, flagged: true);
    await SyncRepository().clearPendingRecords();

    final count = await repo.republishForSync([a.id, b.id]);

    expect(count, 2);
    final pending = await SyncRepository().getPendingRecords();
    expect(pending.map((r) => (r.entityType, r.recordId)).toSet(), {
      ('media', a.id),
      ('media', b.id),
    });
    final after = (await repo.getMediaById(b.id))!;
    expect(after.remoteUploadedAt, DateTime(2026, 2));
    expect(after.isOrphaned, isTrue, reason: 'republish changes no column');
  });

  test('republishing nothing is a no-op', () async {
    await SyncRepository().clearPendingRecords();

    expect(await repo.republishForSync(const []), 0);
    expect(await SyncRepository().getPendingRecords(), isEmpty);
  });
}
