import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late MediaRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.MediaItem localFileItem(String path) => domain.MediaItem(
    id: '',
    mediaType: domain.MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: path,
    localPath: path,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('stampContentIdentity then stampRemoteUploaded round-trips through '
      'getMediaById', () async {
    final created = await repository.createMedia(localFileItem('/tmp/x.jpg'));

    await repository.stampContentIdentity(
      created.id,
      contentHash: 'a' * 64,
      sizeBytes: 12345,
    );
    await repository.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime(2026, 7, 10, 12),
    );

    final loaded = await repository.getMediaById(created.id);
    expect(loaded!.contentHash, 'a' * 64);
    expect(loaded.contentSizeBytes, 12345);
    expect(loaded.remoteUploadedAt, DateTime(2026, 7, 10, 12));
    expect(loaded.remoteThumbUploadedAt, isNull);
  });

  test('createMedia persists contentHash when provided and copyWith can '
      'clear remoteUploadedAt', () async {
    final item = localFileItem(
      '/tmp/y.jpg',
    ).copyWith(contentHash: 'b' * 64, contentSizeBytes: 1);
    final created = await repository.createMedia(item);
    final loaded = await repository.getMediaById(created.id);
    expect(loaded!.contentHash, 'b' * 64);
    expect(loaded.contentSizeBytes, 1);

    final stamped = loaded.copyWith(remoteUploadedAt: DateTime(2026, 2, 2));
    expect(stamped.remoteUploadedAt, DateTime(2026, 2, 2));
    final cleared = stamped.copyWith(remoteUploadedAt: null);
    expect(cleared.remoteUploadedAt, isNull);
    expect(cleared.contentHash, 'b' * 64);
  });

  test('updateMedia round-trips the new fields', () async {
    final created = await repository.createMedia(localFileItem('/tmp/z.jpg'));
    await repository.updateMedia(
      created.copyWith(
        contentHash: 'c' * 64,
        contentSizeBytes: 7,
        remoteUploadedAt: DateTime(2026, 3, 3),
        remoteThumbUploadedAt: DateTime(2026, 3, 4),
      ),
    );
    final loaded = await repository.getMediaById(created.id);
    expect(loaded!.contentHash, 'c' * 64);
    expect(loaded.contentSizeBytes, 7);
    expect(loaded.remoteUploadedAt, DateTime(2026, 3, 3));
    expect(loaded.remoteThumbUploadedAt, DateTime(2026, 3, 4));
  });

  test('stampRemoteThumbUploaded round-trips', () async {
    final created = await repository.createMedia(localFileItem('/tmp/t.jpg'));
    await repository.stampRemoteThumbUploaded(
      created.id,
      uploadedAt: DateTime(2026, 7, 10, 13),
    );
    final loaded = await repository.getMediaById(created.id);
    expect(loaded!.remoteThumbUploadedAt, DateTime(2026, 7, 10, 13));
    expect(loaded.remoteUploadedAt, isNull);
  });
}
