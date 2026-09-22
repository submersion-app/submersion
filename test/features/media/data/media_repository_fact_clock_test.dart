import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Every fact write stamps its own group's clock and leaves the row clock
/// alone, so a stamp can never make a stale caption win the row (media sync
/// program spec 5.1). User edits move only the row clock.
void main() {
  late AppDatabase db;
  late String id;
  final repo = MediaRepository();

  Future<Map<String, String?>> clocks() async {
    final r = await db
        .customSelect(
          'SELECT hlc, upload_facts_hlc, verify_facts_hlc '
          'FROM media WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return {
      'row': r.read<String?>('hlc'),
      'upload': r.read<String?>('upload_facts_hlc'),
      'verify': r.read<String?>('verify_facts_hlc'),
    };
  }

  bool later(String? after, String? before) =>
      after != null && before != null && after.compareTo(before) > 0;

  setUp(() async {
    db = await setUpTestDatabase();
    id = (await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    )).id;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('createMedia stamps both fact clocks with the row clock', () async {
    final c = await clocks();
    expect(c['row'], isNotNull);
    expect(c['upload'], c['row']);
    expect(c['verify'], c['row']);
  });

  final uploadWriters = <String, Future<void> Function(String)>{
    'stampContentIdentity': (i) =>
        repo.stampContentIdentity(i, contentHash: 'h', sizeBytes: 1),
    'stampRemoteUploaded': (i) =>
        repo.stampRemoteUploaded(i, uploadedAt: DateTime(2026)),
    'stampRemoteThumbUploaded': (i) =>
        repo.stampRemoteThumbUploaded(i, uploadedAt: DateTime(2026)),
    'stampRemoteCompressedUploaded': (i) => repo.stampRemoteCompressedUploaded(
      i,
      uploadedAt: DateTime(2026),
      level: 'high',
      sizeBytes: 1,
    ),
    'clearRemoteUploaded': repo.clearRemoteUploaded,
    'clearRemoteThumbUploaded': repo.clearRemoteThumbUploaded,
    'clearRemoteCompressed': repo.clearRemoteCompressed,
  };
  final verifyWriters = <String, Future<void> Function(String)>{
    'markAsOrphaned': repo.markAsOrphaned,
    'markOrphaned': (i) => repo.markOrphaned(i, true),
    'markVerified': (i) =>
        repo.markVerified(i, isOrphaned: true, verifiedAt: DateTime(2026)),
    'stampVerification': (i) =>
        repo.stampVerification(i, verifiedAt: DateTime(2026), isOrphaned: true),
  };

  for (final e in uploadWriters.entries) {
    test('${e.key} stamps the upload clock only', () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await e.value(id);
      final after = await clocks();
      expect(after['row'], before['row'], reason: 'row clock unchanged');
      expect(after['verify'], before['verify']);
      expect(later(after['upload'], before['upload']), isTrue);
    });
  }

  for (final e in verifyWriters.entries) {
    test('${e.key} stamps the verification clock only', () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await e.value(id);
      final after = await clocks();
      expect(after['row'], before['row'], reason: 'row clock unchanged');
      expect(after['upload'], before['upload']);
      expect(later(after['verify'], before['verify']), isTrue);
    });
  }

  test('markAsVerified stamps the verification clock only', () async {
    // Out of the table above because only a FLAG CHANGE stamps now (slice
    // 4): against a row that is already not orphaned this writes the date
    // locally and spends no clock, so the case needs a flag to clear.
    await repo.markOrphaned(id, true);
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await repo.markAsVerified(id);

    final after = await clocks();
    expect(after['row'], before['row'], reason: 'row clock unchanged');
    expect(after['upload'], before['upload']);
    expect(later(after['verify'], before['verify']), isTrue);
  });

  test('markOrphaned stays quiet when the row already agrees', () async {
    // SubscriptionPoller calls this for every entry on every poll, so
    // without the guard a healthy library would take a fresh verification
    // clock each time and re-export its snapshot over a peer's newer
    // observation.
    await repo.markOrphaned(id, true);
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await repo.markOrphaned(id, true);

    final after = await clocks();
    expect(after['verify'], before['verify'], reason: 'no clock was spent');
    expect(after['row'], before['row']);
  });

  test('republishForSync moves the upload clock alone by default', () async {
    // The one caller repairs lost upload stamps. Re-clocking verification
    // too would hand this device's stale isOrphaned and lastVerifiedAt a
    // brand-new clock and beat a peer's newer observation of the same file.
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.republishForSync([id]);
    final after = await clocks();
    expect(after['row'], before['row']);
    expect(later(after['upload'], before['upload']), isTrue);
    expect(after['verify'], before['verify']);
  });

  test('republishForSync re-sends verification when asked for it', () async {
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.republishForSync(
      [id],
      groups: const [SyncFactGroups.mediaVerification],
    );
    final after = await clocks();
    expect(after['row'], before['row']);
    expect(after['upload'], before['upload']);
    expect(later(after['verify'], before['verify']), isTrue);
  });

  test(
    'applyRepairWrites moves the row and verification clocks together',
    () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.applyRepairWrites([
        RepairWrite(mediaId: id, newLocalPath: '/elsewhere/reef.jpg'),
      ]);
      final after = await clocks();
      expect(later(after['row'], before['row']), isTrue);
      expect(after['verify'], after['row']);
      expect(after['upload'], before['upload']);
    },
  );

  test(
    'convertToCloudBacked moves the row and verification clocks together',
    () async {
      await db.customStatement(
        "UPDATE media SET content_hash = 'h', remote_uploaded_at = 1 "
        'WHERE id = ?',
        [id],
      );
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.convertToCloudBacked([id]);
      final after = await clocks();
      expect(later(after['row'], before['row']), isTrue);
      expect(after['verify'], after['row']);
      expect(after['upload'], before['upload']);
    },
  );

  test('a fact-only write leaves a sibling null clock null', () async {
    // The v224 beforeOpen backstop adds the two columns without backfilling,
    // so a row can carry null fact clocks. Initialising the other group's
    // clock on an upload write would hand this device's untouched
    // verification facts a brand-new clock and beat a peer's newer
    // observation; left null they fall back to the row clock.
    await db.customStatement(
      'UPDATE media SET upload_facts_hlc = NULL, verify_facts_hlc = NULL '
      'WHERE id = ?',
      [id],
    );

    await repo.stampRemoteUploaded(id, uploadedAt: DateTime(2026));

    final after = await clocks();
    expect(after['upload'], isNotNull, reason: 'the written group is stamped');
    expect(
      after['verify'],
      isNull,
      reason: 'an untouched group keeps its row-clock fallback',
    );
  });

  test('a stale caller snapshot cannot roll back an upload stamp', () async {
    // Every caller of updateMedia patches a row it read earlier. An upload
    // completing in between is in the row but not in that snapshot, and
    // writing the snapshot's columns back would both undo the upload and,
    // because the values differ, hand the rollback a fresh upload clock.
    final stale = (await repo.getMediaById(id))!;

    await repo.stampContentIdentity(id, contentHash: 'h' * 64, sizeBytes: 42);
    await repo.stampRemoteUploaded(id, uploadedAt: DateTime(2026, 8, 1));
    final stamped = await clocks();

    await repo.updateMedia(stale.copyWith(caption: 'a later caption'));

    final row = (await repo.getMediaById(id))!;
    expect(row.caption, 'a later caption', reason: 'the edit still lands');
    expect(row.contentHash, 'h' * 64, reason: 'the upload fact survives');
    expect(row.remoteUploadedAt, DateTime(2026, 8, 1));
    final after = await clocks();
    expect(
      after['upload'],
      stamped['upload'],
      reason: 'and its clock does not move for a write that did not touch it',
    );
  });

  test('a whole-row write does not touch the verification facts', () async {
    // updateMedia writes user fields only. Its caller patches a row it read
    // earlier, so a verifier that ran in between would be rolled back, and
    // the rollback would then carry a fresh verification clock and beat a
    // peer's newer observation. markOrphaned and friends own those columns.
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final row = (await repo.getMediaById(id))!;

    await repo.updateMedia(
      row.copyWith(isOrphaned: true, caption: 'a new caption'),
    );

    final after = await clocks();
    expect((await repo.getMediaById(id))!.caption, 'a new caption');
    expect(
      (await repo.getMediaById(id))!.isOrphaned,
      isFalse,
      reason: 'the verification fact is not this writer\'s to move',
    );
    expect(later(after['row'], before['row']), isTrue, reason: 'a user edit');
    expect(after['verify'], before['verify']);
    expect(after['upload'], before['upload']);
  });

  test(
    'a whole-row write that changes no fact leaves the fact clocks',
    () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final row = (await repo.getMediaById(id))!;

      await repo.updateMedia(row.copyWith(caption: 'a new caption'));

      final after = await clocks();
      expect(later(after['row'], before['row']), isTrue);
      expect(after['upload'], before['upload']);
      expect(after['verify'], before['verify']);
    },
  );

  test('a user edit moves only the row clock', () async {
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.setManualElapsedSeconds(id, 30);
    final after = await clocks();
    expect(later(after['row'], before['row']), isTrue);
    expect(after['upload'], before['upload']);
    expect(after['verify'], before['verify']);
  });
}
