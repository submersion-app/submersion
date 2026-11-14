import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// What media placement reads and writes on a dive (issue #4539): when its
/// primary computer began recording, and the shift that corrects the camera.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) async {
    final start = DateTime.utc(2026, 5, 6, 9, 4).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(start),
            entryTime: Value(start),
            createdAt: Value(start),
            updatedAt: Value(start),
          ),
        );
  }

  Future<void> insertSource(
    String id, {
    required String diveId,
    required bool isPrimary,
    DateTime? entryTime,
    int? timeOffsetSeconds,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            isPrimary: Value(isPrimary),
            entryTime: Value(entryTime),
            timeOffsetSeconds: Value(timeOffsetSeconds),
            importedAt: DateTime.utc(2026, 10, 6),
            createdAt: DateTime.utc(2026, 10, 6),
          ),
        );
  }

  group('getPrimarySourceEntry', () {
    test('is null for a dive with no data source', () async {
      await insertDive('d1');

      expect(await repo.getPrimarySourceEntry('d1'), isNull);
    });

    test('is when the primary source began recording', () async {
      await insertDive('d1');
      await insertSource(
        'primary',
        diveId: 'd1',
        isPrimary: true,
        entryTime: DateTime.utc(2026, 5, 6, 9, 4, 39),
      );
      await insertSource(
        'second',
        diveId: 'd1',
        isPrimary: false,
        entryTime: DateTime.utc(2026, 5, 6, 9, 4, 44),
        timeOffsetSeconds: 5,
      );

      final entry = await repo.getPrimarySourceEntry('d1');

      expect(entry, DateTime.utc(2026, 5, 6, 9, 4, 39));
      expect(entry!.isUtc, isTrue);
    });

    test('is null when the primary source recorded no entry time', () async {
      await insertDive('d1');
      await insertSource('primary', diveId: 'd1', isPrimary: true);

      expect(await repo.getPrimarySourceEntry('d1'), isNull);
    });

    test('ignores a source that is not the primary', () async {
      await insertDive('d1');
      await insertSource(
        'second',
        diveId: 'd1',
        isPrimary: false,
        entryTime: DateTime.utc(2026, 5, 6, 9, 4, 44),
      );

      expect(await repo.getPrimarySourceEntry('d1'), isNull);
    });

    // A primary that sits some seconds along the dive's timeline began that
    // long after the timeline's zero.
    test('steps back by the offset the primary sits at', () async {
      await insertDive('d1');
      await insertSource(
        'primary',
        diveId: 'd1',
        isPrimary: true,
        entryTime: DateTime.utc(2026, 5, 6, 9, 4, 44),
        timeOffsetSeconds: 5,
      );

      expect(
        await repo.getPrimarySourceEntry('d1'),
        DateTime.utc(2026, 5, 6, 9, 4, 39),
      );
    });
  });

  group('setMediaTimeOffsetSeconds', () {
    test('a dive starts with no shift', () async {
      await insertDive('d1');

      expect((await repo.getDiveById('d1'))!.mediaTimeOffsetSeconds, 0);
    });

    test('stores the shift on the dive', () async {
      await insertDive('d1');

      await repo.setMediaTimeOffsetSeconds('d1', -47);

      expect((await repo.getDiveById('d1'))!.mediaTimeOffsetSeconds, -47);
    });

    test('advances the dive HLC so the shift exports', () async {
      await insertDive('d1');
      final sync = SyncRepository();
      await sync.markRecordPending(
        entityType: 'dives',
        recordId: 'd1',
        localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final watermark =
          (await db
                  .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
                  .getSingle())
              .read<String>('hlc');
      final serializer = SyncDataSerializer();
      final deviceId = await sync.getDeviceId();

      await repo.setMediaTimeOffsetSeconds('d1', -47);

      final after = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: watermark,
        deletions: const [],
      );
      final exported = after.data.dives.firstWhere((d) => d['id'] == 'd1');
      expect(
        exported['mediaTimeOffsetSeconds'],
        -47,
        reason: 'the shift must ride the dive row to other devices',
      );
    });

    Future<String?> hlc() async =>
        (await db
                .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
                .getSingle())
            .readNullable<String>('hlc');

    // The dive row carries its own clock: stamping it for a value it
    // already holds ships a no-op to every device.
    test('the shift a dive already has is not written again', () async {
      await insertDive('d1');
      await repo.setMediaTimeOffsetSeconds('d1', -47);
      final stamped = await hlc();

      await repo.setMediaTimeOffsetSeconds('d1', -47);

      expect(await hlc(), stamped);
    });

    test('a dive with no shift is not stamped for a shift of 0', () async {
      await insertDive('d1');
      final before = await hlc();

      await repo.setMediaTimeOffsetSeconds('d1', 0);

      expect(await hlc(), before);
    });

    test('saving the dive leaves the shift alone', () async {
      await insertDive('d1');
      await repo.setMediaTimeOffsetSeconds('d1', -47);
      final stale = (await repo.getDiveById(
        'd1',
      ))!.copyWith(notes: 'edited', mediaTimeOffsetSeconds: 0);

      await repo.updateDive(stale);

      expect((await repo.getDiveById('d1'))!.mediaTimeOffsetSeconds, -47);
    });
  });
}
