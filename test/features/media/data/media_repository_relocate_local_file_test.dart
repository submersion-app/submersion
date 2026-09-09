import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Coverage for [MediaRepository.relocateLocalFile], the row half of the
/// scanned-logs folder migration (issue #1645).
///
/// A scan's media row carries the copy's absolute path in `file_path` (and,
/// for rows the v72 backfill touched, in `local_path` too), so moving the file
/// on disk without rewriting the row would strand it as "File not found".
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

  MediaItem scan({
    required String filePath,
    String? localPath,
    String diveId = 'd1',
  }) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: filePath,
    localPath: localPath,
    originalFilename: 'page.jpg',
    diveId: diveId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  const from = '/docs/scanned_logs/1.jpg';
  const to = '/docs/Submersion/scanned_logs/1.jpg';

  test('rewrites file_path on a row that only carries file_path', () async {
    await insertDive('d1');
    final created = await repo.createMedia(scan(filePath: from));

    final count = await repo.relocateLocalFile(from: from, to: to);

    expect(count, 1);
    final row = await repo.getMediaById(created.id);
    expect(row!.filePath, to);
    expect(row.localPath, isNull);
  });

  test('rewrites both columns when local_path mirrors file_path', () async {
    await insertDive('d1');
    final created = await repo.createMedia(
      scan(filePath: from, localPath: from),
    );

    await repo.relocateLocalFile(from: from, to: to);

    final row = await repo.getMediaById(created.id);
    expect(row!.filePath, to);
    expect(row.localPath, to);
  });

  test('leaves rows at other paths alone', () async {
    await insertDive('d1');
    const other = '/docs/scanned_logs/2.jpg';
    final untouched = await repo.createMedia(scan(filePath: other));
    await repo.createMedia(scan(filePath: from));

    final count = await repo.relocateLocalFile(from: from, to: to);

    expect(count, 1);
    final row = await repo.getMediaById(untouched.id);
    expect(row!.filePath, other);
  });

  test(
    'marks every relocated row pending so peers learn the new path',
    () async {
      await insertDive('d1');
      final a = await repo.createMedia(scan(filePath: from));
      final b = await repo.createMedia(scan(filePath: from, localPath: from));
      final untouched = await repo.createMedia(
        scan(filePath: '/docs/scanned_logs/2.jpg'),
      );
      // createMedia already marks rows pending; clear the slate so the
      // assertion below is about relocateLocalFile alone.
      await db.delete(db.syncRecords).go();

      await repo.relocateLocalFile(from: from, to: to);

      final pending = await SyncRepository().getPendingRecords();
      expect(pending.map((r) => r.recordId).toSet(), {a.id, b.id});
      expect(pending.map((r) => r.recordId), isNot(contains(untouched.id)));
    },
  );

  test(
    'rethrows a database failure so the migration can leave the file',
    () async {
      // The migration copies the page first and only deletes the legacy copy
      // after the rows are relinked, so a swallowed error here would strand a
      // row on a path that is about to disappear. The error must surface.
      // Dropping the table rather than closing the database: a closed
      // in-memory database quietly answers a select with no rows.
      await db.customStatement('DROP TABLE media');

      await expectLater(
        repo.relocateLocalFile(from: from, to: to),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('returns zero and marks nothing when no row matches', () async {
    await insertDive('d1');
    await repo.createMedia(scan(filePath: '/elsewhere/1.jpg'));
    await db.delete(db.syncRecords).go();

    final count = await repo.relocateLocalFile(from: from, to: to);

    expect(count, 0);
    expect(await SyncRepository().getPendingRecords(), isEmpty);
  });
}
