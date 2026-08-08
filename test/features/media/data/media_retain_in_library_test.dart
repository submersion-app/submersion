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

  MediaItem item(String id, {bool retainInLibrary = false}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    retainInLibrary: retainInLibrary,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test('retainInLibrary round-trips through create and read', () async {
    await repo.createMedia(item('keep.jpg', retainInLibrary: true));
    await repo.createMedia(item('normal.jpg'));

    final kept = await repo.getMediaById('keep.jpg');
    final normal = await repo.getMediaById('normal.jpg');
    expect(kept!.retainInLibrary, isTrue);
    expect(normal!.retainInLibrary, isFalse);
    expect(db, isNotNull);
  });

  test('updateMedia persists a retainInLibrary change', () async {
    final created = await repo.createMedia(item('m1'));
    await repo.updateMedia(created.copyWith(retainInLibrary: true));
    expect((await repo.getMediaById(created.id))!.retainInLibrary, isTrue);
  });
}
