import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1090: the diver's manual position for a media item lives on the
/// media row so it syncs with the row and outlives every enrichment
/// recompute.
void main() {
  late AppDatabase db;
  late MediaRepository repository;
  late String diveId;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = MediaRepository();
    final dive = await DiveRepository().createDive(
      domain.Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 1, 1, 10),
      ),
    );
    diveId = dive.id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  MediaItem item({int? manualElapsedSeconds}) {
    final now = DateTime.utc(2026, 1, 1, 10, 5);
    return MediaItem(
      id: '',
      diveId: diveId,
      filePath: '/photos/a.jpg',
      mediaType: MediaType.photo,
      takenAt: now,
      manualElapsedSeconds: manualElapsedSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<String>> syncStatusesFor(String id) async {
    final rows = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals(id))).get();
    return rows.map((r) => r.syncStatus).toList();
  }

  test('createMedia persists the manual position', () async {
    final created = await repository.createMedia(
      item(manualElapsedSeconds: 720),
    );
    final fetched = await repository.getMediaById(created.id);
    expect(fetched!.manualElapsedSeconds, 720);
  });

  test('a row without a pin reads back as automatic', () async {
    final created = await repository.createMedia(item());
    final fetched = await repository.getMediaById(created.id);
    expect(fetched!.manualElapsedSeconds, isNull);
  });

  test('updateMedia persists a changed manual position', () async {
    final created = await repository.createMedia(item());
    await repository.updateMedia(created.copyWith(manualElapsedSeconds: 90));
    final fetched = await repository.getMediaById(created.id);
    expect(fetched!.manualElapsedSeconds, 90);
  });

  group('setManualElapsedSeconds', () {
    test('pins the item and marks the row sync-pending', () async {
      final created = await repository.createMedia(item());
      // createMedia already queued a pending record; clear it so the
      // assertion below is about this write alone.
      await (db.delete(
        db.syncRecords,
      )..where((t) => t.recordId.equals(created.id))).go();

      await repository.setManualElapsedSeconds(created.id, 1500);

      final fetched = await repository.getMediaById(created.id);
      expect(fetched!.manualElapsedSeconds, 1500);
      expect(await syncStatusesFor(created.id), contains('pending'));
    });

    test('null clears the pin back to automatic', () async {
      final created = await repository.createMedia(
        item(manualElapsedSeconds: 1500),
      );

      await repository.setManualElapsedSeconds(created.id, null);

      final fetched = await repository.getMediaById(created.id);
      expect(fetched!.manualElapsedSeconds, isNull);
    });

    test('bumps updatedAt so the change wins on sync', () async {
      final created = await repository.createMedia(item());
      final before = (await repository.getMediaById(created.id))!.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repository.setManualElapsedSeconds(created.id, 30);

      final after = (await repository.getMediaById(created.id))!.updatedAt;
      expect(after.isAfter(before), isTrue);
    });
  });
}
