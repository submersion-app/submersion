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

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertDive(String id, {String? diverId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(
    String name,
    DateTime takenAt, {
    String? diveId,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: MediaSourceType.platformGallery,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    takenAt: takenAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('returns newest media first, capped at limit', () async {
    await insertDive('d1');
    await repo.createMedia(item('jan.jpg', DateTime(2026, 1, 1), diveId: 'd1'));
    await repo.createMedia(item('mar.jpg', DateTime(2026, 3, 1), diveId: 'd1'));
    await repo.createMedia(item('feb.jpg', DateTime(2026, 2, 1), diveId: 'd1'));

    final result = await repo.getRecentMedia(limit: 2);
    expect(result, hasLength(2));
    // takenAt hydrates as UTC; compare instants, not DateTime objects.
    expect(result[0].takenAt.toLocal(), DateTime(2026, 3, 1));
    expect(result[1].takenAt.toLocal(), DateTime(2026, 2, 1));
  });

  test('includes videos, interleaved with photos by date', () async {
    await insertDive('d1');
    await repo.createMedia(item('mar.jpg', DateTime(2026, 3, 1), diveId: 'd1'));
    await repo.createMedia(
      item(
        'apr.mov',
        DateTime(2026, 4, 1),
        diveId: 'd1',
        mediaType: MediaType.video,
      ),
    );
    await repo.createMedia(
      item(
        'feb.mov',
        DateTime(2026, 2, 1),
        diveId: 'd1',
        mediaType: MediaType.video,
      ),
    );

    final result = await repo.getRecentMedia();
    expect(result.map((m) => m.originalFilename), [
      'apr.mov',
      'mar.jpg',
      'feb.mov',
    ]);
  });

  // Signatures and documents are attachments, not things a diver browses in a
  // recency ribbon, so widening beyond photos must not pull them in.
  test('still excludes signatures and documents', () async {
    await insertDive('d1');
    await repo.createMedia(
      item('photo.jpg', DateTime(2026, 1, 1), diveId: 'd1'),
    );
    await repo.createMedia(
      item(
        'sig.png',
        DateTime(2026, 5, 1),
        diveId: 'd1',
        mediaType: MediaType.instructorSignature,
      ),
    );
    await repo.createMedia(
      item(
        'manual.pdf',
        DateTime(2026, 6, 1),
        diveId: 'd1',
        mediaType: MediaType.document,
      ),
    );

    final result = await repo.getRecentMedia();
    expect(result.map((m) => m.originalFilename), ['photo.jpg']);
  });

  test('excludes media not attached to a dive', () async {
    await insertDive('d1');
    await repo.createMedia(
      item('library.jpg', DateTime(2026, 5, 1)), // newest, but no dive
    );
    await repo.createMedia(
      item('dive.jpg', DateTime(2026, 4, 1), diveId: 'd1'),
    );

    final result = await repo.getRecentMedia();
    expect(result.map((m) => m.originalFilename), ['dive.jpg']);
  });

  group('diver scope', () {
    setUp(() async {
      await insertDiver('alice');
      await insertDiver('bob');
      await insertDive('alice-dive', diverId: 'alice');
      await insertDive('bob-dive', diverId: 'bob');
      await repo.createMedia(
        item('alice.jpg', DateTime(2026, 3, 1), diveId: 'alice-dive'),
      );
      await repo.createMedia(
        item('bob.jpg', DateTime(2026, 4, 1), diveId: 'bob-dive'),
      );
    });

    test('returns only media from the given diver\'s dives', () async {
      final result = await repo.getRecentMedia(diverId: 'alice');
      expect(result.map((m) => m.originalFilename), ['alice.jpg']);
    });

    // A secondary diver with no dives of their own must see an empty ribbon,
    // not the primary diver's photos.
    test('is empty for a diver with no dives', () async {
      await insertDiver('carol');
      expect(await repo.getRecentMedia(diverId: 'carol'), isEmpty);
    });

    test('a null diver id stays unscoped', () async {
      final result = await repo.getRecentMedia();
      expect(result.map((m) => m.originalFilename), ['bob.jpg', 'alice.jpg']);
    });
  });

  test('empty table returns empty list', () async {
    expect(await repo.getRecentMedia(), isEmpty);
  });
}
