import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import '../../../helpers/test_database.dart';

void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  MediaItem photo(String id, {String? hash}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    contentHash: hash,
  );

  test('stampRemoteCompressedUploaded persists level, size, stamp', () async {
    await repo.createMedia(photo('m1', hash: 'h1'));
    await repo.stampRemoteCompressedUploaded(
      'm1',
      uploadedAt: DateTime(2026, 2, 2),
      level: 'balanced',
      sizeBytes: 4321,
    );
    final got = await repo.getMediaById('m1');
    expect(got!.remoteCompressedUploadedAt, DateTime(2026, 2, 2));
    expect(got.compressedLevel, 'balanced');
    expect(got.compressedSizeBytes, 4321);
  });

  test('clearRemoteUploaded nulls the original stamp', () async {
    await repo.createMedia(
      photo('m2', hash: 'h2').copyWith(remoteUploadedAt: DateTime(2026, 1, 2)),
    );
    await repo.clearRemoteUploaded('m2');
    expect((await repo.getMediaById('m2'))!.remoteUploadedAt, isNull);
  });

  test(
    'countRowsWithOriginal counts only rows with remoteUploadedAt set',
    () async {
      await repo.createMedia(
        photo('a', hash: 'h9').copyWith(remoteUploadedAt: DateTime(2026, 1, 2)),
      );
      await repo.createMedia(photo('b', hash: 'h9')); // no original stamp
      expect(await repo.countRowsWithOriginal('h9'), 1);
    },
  );

  test(
    'countRowsWithRendition counts rows with the compressed stamp',
    () async {
      await repo.createMedia(
        photo(
          'c',
          hash: 'h4',
        ).copyWith(remoteCompressedUploadedAt: DateTime(2026, 1, 3)),
      );
      expect(await repo.countRowsWithRendition('h4'), 1);
      expect(await repo.countRowsWithRendition('nope'), 0);
    },
  );

  test(
    'countRowsWithHash counts every row with the hash, uploaded or not',
    () async {
      await repo.createMedia(
        photo('u1', hash: 'hh').copyWith(remoteUploadedAt: DateTime(2026)),
      );
      await repo.createMedia(photo('u2', hash: 'hh')); // never uploaded
      await repo.createMedia(photo('u3', hash: 'other'));
      expect(await repo.countRowsWithHash('hh'), 2);
      expect(await repo.countRowsWithHash('nope'), 0);
    },
  );

  test('compressed-only photo is NOT a backfill candidate', () async {
    await repo.createMedia(
      photo(
        'd',
        hash: 'h3',
      ).copyWith(remoteCompressedUploadedAt: DateTime(2026, 1, 3)),
    );
    expect(await repo.getBackfillCandidateIds(), isNot(contains('d')));
  });
}
