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

  Future<void> stampUploaded(String id, {String? store}) async {
    await repo.stampContentIdentity(id, contentHash: 'hash-$id', sizeBytes: 9);
    await db.customStatement(
      'UPDATE media SET remote_uploaded_at = 123, remote_store_id = ? '
      'WHERE id = ?',
      [store, id],
    );
  }

  test('converts stamped rows and clears local pointers', () async {
    await repo.createMedia(item('m1'));
    await stampUploaded('m1');

    final converted = await repo.convertToCloudBacked([
      'm1',
    ], storeId: 'store-b');

    expect(converted, {'m1'});

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

    final converted = await repo.convertToCloudBacked([
      'unstamped',
    ], storeId: 'store-b');

    expect(converted, isEmpty);

    final m = await repo.getMediaById('unstamped');
    expect(m!.sourceType, MediaSourceType.localFile);
    expect(m.localPath, '/tmp/unstamped');
    expect(m.isOrphaned, isTrue);
  });

  test('empty id list is a no-op', () async {
    expect(
      await repo.convertToCloudBacked(const [], storeId: 'store-b'),
      isEmpty,
    );
  });

  group('the stamp must belong to the attached store (issue #3482)', () {
    test('refuses a row whose only copy is in another store', () async {
      await repo.createMedia(item('p'));
      await stampUploaded('p', store: 'store-a');

      final converted = await repo.convertToCloudBacked([
        'p',
      ], storeId: 'store-b');

      expect(converted, isEmpty);
      final m = await repo.getMediaById('p');
      expect(m!.sourceType, MediaSourceType.localFile);
      expect(m.localPath, '/tmp/p');
      expect(m.bookmarkRef, 'bookmark-p');
      expect(m.isOrphaned, isTrue);
    });

    test('converts a row stamped for the attached store', () async {
      await repo.createMedia(item('p'));
      await stampUploaded('p', store: 'store-b');

      final converted = await repo.convertToCloudBacked([
        'p',
      ], storeId: 'store-b');

      expect(converted, {'p'});
      final m = await repo.getMediaById('p');
      expect(m!.sourceType, MediaSourceType.mediaStore);
    });

    test('converts only the qualifying rows of a mixed batch', () async {
      await repo.createMedia(item('a'));
      await repo.createMedia(item('b'));
      await repo.createMedia(item('n'));
      await stampUploaded('a', store: 'store-a');
      await stampUploaded('b', store: 'store-b');
      await stampUploaded('n');

      final converted = await repo.convertToCloudBacked([
        'a',
        'b',
        'n',
      ], storeId: 'store-b');

      expect(converted, {'b', 'n'});
      expect(
        (await repo.getMediaById('a'))!.sourceType,
        MediaSourceType.localFile,
      );
    });
  });
}
