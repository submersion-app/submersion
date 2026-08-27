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

  MediaItem item(String id) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    bookmarkRef: 'bookmark-$id',
    platformAssetId: 'asset-$id',
    isOrphaned: true,
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  Future<void> stampUploaded(String id) async {
    await repo.stampContentIdentity(id, contentHash: 'hash-$id', sizeBytes: 9);
    await db.customStatement(
      'UPDATE media SET remote_uploaded_at = 123 WHERE id = ?',
      [id],
    );
  }

  test('converts stamped rows and clears local pointers', () async {
    await repo.createMedia(item('m1'));
    await stampUploaded('m1');

    await repo.convertToCloudBacked(['m1']);

    final m = await repo.getMediaById('m1');
    expect(m!.sourceType, MediaSourceType.mediaStore);
    expect(m.localPath, isNull);
    expect(m.bookmarkRef, isNull);
    expect(m.platformAssetId, isNull);
    expect(m.isOrphaned, isFalse);
    expect(m.lastVerifiedAt, isNotNull);
  });

  test('skips rows without the stamp pair', () async {
    await repo.createMedia(item('unstamped'));

    await repo.convertToCloudBacked(['unstamped']);

    final m = await repo.getMediaById('unstamped');
    expect(m!.sourceType, MediaSourceType.localFile);
    expect(m.localPath, '/tmp/unstamped');
    expect(m.isOrphaned, isTrue);
  });

  test('empty id list is a no-op', () async {
    await repo.convertToCloudBacked(const []);
  });
}
