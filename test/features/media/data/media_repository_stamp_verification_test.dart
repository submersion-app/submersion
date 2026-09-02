import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The verifier persists what a check learned through this write. It has to
/// be narrow: the verifier's callers hold a snapshot of the row, and an upload
/// that completes after the snapshot was taken stamps `remoteUploadedAt` on
/// the row. A whole-row write from the snapshot would roll that stamp back to
/// null, and `markRecordPending` would then sync the rollback to every other
/// device (the bug behind "no backup available" on a second device).
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<MediaItem> stampedPhoto() async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/reef.jpg',
        localPath: '/tmp/reef.jpg',
        originalFilename: 'reef.jpg',
        diveId: 'dive-1',
        contentHash: 'aabbccdd',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.stampRemoteUploaded(created.id, uploadedAt: DateTime(2026, 2));
    await repo.stampRemoteThumbUploaded(
      created.id,
      uploadedAt: DateTime(2026, 2),
    );
    return created;
  }

  test('a finding moves the flag and the date and nothing else', () async {
    final photo = await stampedPhoto();
    final checkedAt = DateTime(2026, 3, 1, 12);

    await repo.stampVerification(
      photo.id,
      verifiedAt: checkedAt,
      isOrphaned: true,
    );

    final row = (await repo.getMediaById(photo.id))!;
    expect(row.isOrphaned, isTrue);
    expect(row.lastVerifiedAt, checkedAt);
    expect(row.remoteUploadedAt, DateTime(2026, 2));
    expect(row.remoteThumbUploadedAt, DateTime(2026, 2));
    expect(row.contentHash, 'aabbccdd');
  });

  test('a reachability outcome stamps the date and leaves the flag', () async {
    final photo = await stampedPhoto();
    await repo.stampVerification(
      photo.id,
      verifiedAt: DateTime(2026, 3, 1),
      isOrphaned: true,
    );

    await repo.stampVerification(photo.id, verifiedAt: DateTime(2026, 3, 2));

    final row = (await repo.getMediaById(photo.id))!;
    expect(row.isOrphaned, isTrue, reason: 'nothing was learned about it');
    expect(row.lastVerifiedAt, DateTime(2026, 3, 2));
  });

  test('a row that is gone by the time the check lands leaves nothing '
      'pending', () async {
    // Check all media runs asynchronously over a snapshot of rows; a row
    // deleted meanwhile must not gain a pending sync record pointing at
    // nothing (markVerified guards the same way).
    await SyncRepository().clearPendingRecords();

    await repo.stampVerification(
      'no-such-row',
      verifiedAt: DateTime(2026, 3),
      isOrphaned: true,
    );

    expect(await SyncRepository().getPendingRecords(), isEmpty);
  });

  test('the write is sync-visible', () async {
    final photo = await stampedPhoto();
    // createMedia and the stamps above already queued the row; clear that
    // so the assertion is about this write alone.
    await SyncRepository().clearPendingRecords();

    await repo.stampVerification(photo.id, verifiedAt: DateTime(2026, 3));

    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => (r.entityType, r.recordId)),
      contains(('media', photo.id)),
    );
  });
}
