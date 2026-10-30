import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<String> row(
    String filename, {
    MediaType type = MediaType.photo,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        filePath: '/x/$filename',
        originalFilename: filename,
        mediaType: type,
        sourceType: MediaSourceType.localFile,
        takenAt: DateTime.utc(2026, 7, 1),
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      ),
    );
    return created.id;
  }

  test('groups every hashed row by hash with its key facts', () async {
    final a = await row('a.JPG');
    final b = await row('b.jpeg');
    final v = await row('clip.mov', type: MediaType.video);
    await row('unhashed.png');
    await repo.stampContentIdentity(a, contentHash: 'abc123', sizeBytes: 1);
    await repo.stampContentIdentity(b, contentHash: 'abc123', sizeBytes: 1);
    await repo.stampContentIdentity(v, contentHash: 'def456', sizeBytes: 1);
    await repo.stampRemoteUploaded(a, uploadedAt: DateTime.utc(2026, 7, 2));
    await repo.stampRemoteCompressedUploaded(
      v,
      uploadedAt: DateTime.utc(2026, 7, 2),
      level: 'medium',
      sizeBytes: 1,
    );

    final refs = await repo.getContentReferences();

    expect(refs.keys, unorderedEquals(['abc123', 'def456']));
    final photo = refs['abc123']!;
    expect(
      photo.map((r) => r.originalExtension),
      unorderedEquals(['jpg', 'jpeg']),
    );
    final stamped = photo.singleWhere((r) => r.originalExtension == 'jpg');
    expect(stamped.hasOriginalStamp, isTrue);
    expect(stamped.hasRenditionStamp, isFalse);
    expect(stamped.isVideo, isFalse);
    final clip = refs['def456']!.single;
    expect(clip.isVideo, isTrue);
    expect(clip.hasRenditionStamp, isTrue);
    expect(clip.originalExtension, 'mov');
  });
}
