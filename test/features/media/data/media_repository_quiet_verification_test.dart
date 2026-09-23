import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Checking a library must not rewrite it: the four verification writers
/// publish only when the orphan flag actually moves (media sync program
/// spec 5.2). The check date is a local observation and rides along on the
/// row's next sync-visible write.
void main() {
  late AppDatabase db;
  late String id;
  final repo = MediaRepository();

  Future<bool> isPending() async => (await SyncRepository().getPendingRecords())
      .any((r) => r.entityType == 'media' && r.recordId == id);

  Future<String?> verifyClock() async =>
      (await db
              .customSelect(
                'SELECT verify_facts_hlc FROM media WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String?>('verify_facts_hlc');

  Future<bool> orphaned() async => (await repo.getMediaById(id))!.isOrphaned;

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
    await SyncRepository().clearPendingRecords();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  group('stampVerification', () {
    test('publishes when the flag moves', () async {
      final before = await verifyClock();
      await repo.stampVerification(
        id,
        verifiedAt: DateTime(2026, 8),
        isOrphaned: true,
      );
      expect(await orphaned(), isTrue);
      expect(await isPending(), isTrue);
      expect(await verifyClock(), isNot(before));
    });

    test('a date-only check records the date and publishes nothing', () async {
      final before = await verifyClock();
      await repo.stampVerification(id, verifiedAt: DateTime(2026, 8));
      expect((await repo.getMediaById(id))!.lastVerifiedAt, DateTime(2026, 8));
      expect(await isPending(), isFalse);
      expect(await verifyClock(), before, reason: 'no clock was spent');
    });

    test('a date-only check does not wake the sync check', () async {
      // The date never leaves this device, so a listener woken here would
      // schedule a network sync with nothing to send. Check all walks the
      // whole library, so a healthy one would wake it once per row. The
      // media queries watch the table itself and refresh without this.
      final seen = <void>[];
      final sub = SyncEventBus.changes.listen(seen.add);
      addTearDown(sub.cancel);

      await repo.stampVerification(id, verifiedAt: DateTime(2026, 8));
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: 'nothing became publishable');
    });

    test('confirming the current flag publishes nothing', () async {
      await repo.stampVerification(
        id,
        verifiedAt: DateTime(2026, 8),
        isOrphaned: false,
      );
      expect(await isPending(), isFalse);
    });

    test('the quiet date stays local, even after a later edit', () async {
      // The date is not carried to peers by the row's next edit: that edit
      // moves the ROW clock, and the merge compares each fact group on its
      // own clock, so a peer with an equal or newer verification clock
      // keeps its own date. Local until the flag moves, by design.
      final before = await verifyClock();
      await repo.stampVerification(id, verifiedAt: DateTime(2026, 8));

      final row = (await repo.getMediaById(id))!;
      await repo.updateMedia(row.copyWith(caption: 'a later caption'));

      expect(
        await verifyClock(),
        before,
        reason: 'a user edit does not lend the date a verification clock',
      );
      expect((await repo.getMediaById(id))!.lastVerifiedAt, DateTime(2026, 8));
    });

    test('a row that is gone publishes nothing', () async {
      await repo.stampVerification(
        'no-such-row',
        verifiedAt: DateTime(2026, 8),
        isOrphaned: true,
      );
      expect(await SyncRepository().getPendingRecords(), isEmpty);
    });
  });

  group('the other flag writers', () {
    test('markOrphaned publishes once, then stays quiet', () async {
      await repo.markOrphaned(id, true);
      expect(await isPending(), isTrue);

      await SyncRepository().clearPendingRecords();
      await repo.markOrphaned(id, true);
      expect(await isPending(), isFalse, reason: 'the row already agrees');
    });

    test('markAsOrphaned publishes once, then stays quiet', () async {
      await repo.markAsOrphaned(id);
      expect(await isPending(), isTrue);

      await SyncRepository().clearPendingRecords();
      await repo.markAsOrphaned(id);
      expect(await isPending(), isFalse);
    });

    test(
      'markAsVerified on an already-verified row publishes nothing',
      () async {
        // The row starts not orphaned, so this only restates the flag.
        await repo.markAsVerified(id);
        expect(await isPending(), isFalse);
        expect(
          (await repo.getMediaById(id))!.lastVerifiedAt,
          isNotNull,
          reason: 'the date is still recorded locally',
        );
      },
    );

    test('a no-op flag write announces nothing', () async {
      // SubscriptionPoller reaches these for every manifest entry on every
      // poll. A row that was not written must not wake the sync check.
      await repo.markAsOrphaned(id);
      final seen = <void>[];
      final sub = SyncEventBus.changes.listen(seen.add);
      addTearDown(sub.cancel);

      await repo.markAsOrphaned(id);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: 'the row already agreed');
    });

    test('a date-only markAsVerified does not wake the sync check', () async {
      // The row is already not orphaned, so this records a date and no
      // more. Same reasoning as the date-only stampVerification.
      final seen = <void>[];
      final sub = SyncEventBus.changes.listen(seen.add);
      addTearDown(sub.cancel);

      await repo.markAsVerified(id);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: 'nothing became publishable');
    });

    test('markAsVerified publishes when it clears the flag', () async {
      await repo.markOrphaned(id, true);
      await SyncRepository().clearPendingRecords();

      await repo.markAsVerified(id);

      expect(await orphaned(), isFalse);
      expect(await isPending(), isTrue);
    });
  });
}
