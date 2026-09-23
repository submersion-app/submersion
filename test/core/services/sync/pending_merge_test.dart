import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A locally pending row used to skip the peer's copy outright, and the
/// changeset cursor still advanced, so a newer edit made elsewhere never
/// landed and the peer then refused this device's older copy: the devices
/// diverged for good. Where both sides carry a clock they are now ordered.
void main() {
  late AppDatabase db;

  SyncPayload payloadWith({List<Map<String, dynamic>> dives = const []}) =>
      SyncPayload(
        version: 1,
        exportedAt: 0,
        deviceId: 'peer',
        checksum: '',
        data: SyncData(dives: dives),
        deletions: const {},
      );

  SyncService service() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  );

  Future<String?> notesOf(String id) async =>
      (await db
              .customSelect(
                'SELECT notes FROM dives WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String?>('notes');

  Future<bool> pending(String type, String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == type && r.recordId == id,
      );

  /// A local edit to d1's notes, marked pending as the app's editors do.
  Future<void> editLocally(String notes) async {
    await db.customStatement('UPDATE dives SET notes = ? WHERE id = ?', [
      notes,
      'd1',
    ]);
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: 'd1',
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test(
    'a pending row takes a strictly newer peer edit and stays pending',
    () async {
      await editLocally('mine');
      final local = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
      final newer = SyncClock.instance.issue()!;

      await service().debugApplyPayload(
        payloadWith(
          dives: [
            {...local, 'notes': 'theirs', 'hlc': newer},
          ],
        ),
      );

      expect(await notesOf('d1'), 'theirs');
      expect(
        await pending('dives', 'd1'),
        isTrue,
        reason: 'the mark is kept; the next publish carries what won',
      );
    },
  );

  test('a pending row keeps its edit against an older peer copy', () async {
    final before = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await editLocally('mine');

    await service().debugApplyPayload(
      payloadWith(
        dives: [
          {...before, 'notes': 'stale'},
        ],
      ),
    );

    expect(await notesOf('d1'), 'mine');
  });

  test('a pending row still skips a peer copy that carries no clock', () async {
    await editLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
    final unclocked = {...local, 'notes': 'unordered'}..remove('hlc');

    await service().debugApplyPayload(payloadWith(dives: [unclocked]));

    expect(
      await notesOf('d1'),
      'mine',
      reason: 'nothing orders an unpublished edit against it',
    );
  });

  test(
    'two devices converge when one edits while the other is pending',
    () async {
      // Two real devices over one fake cloud, the pattern of
      // test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart.
      final cloud = FakeCloudStorageProvider();
      final dbA = db;
      SyncService buildService() => SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      void switchTo(AppDatabase d) {
        DatabaseService.instance.setTestDatabase(d);
        SyncClock.instance.reset();
        db = d;
      }

      switchTo(dbA);
      expect((await buildService().performSync()).isSuccess, isTrue);
      final dbB = createTestDatabase();
      addTearDown(dbB.close);
      switchTo(dbB);
      expect((await buildService().performSync()).isSuccess, isTrue);
      expect(await notesOf('d1'), isNotNull, reason: 'B has the dive');

      // B edits offline first; A edits later, so A's clock is newer.
      await editLocally('from B');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      switchTo(dbA);
      await editLocally('from A');
      expect((await buildService().performSync()).isSuccess, isTrue);

      switchTo(dbB);
      expect((await buildService().performSync()).isSuccess, isTrue);
      expect(await notesOf('d1'), 'from A', reason: 'B took the newer edit');

      switchTo(dbA);
      expect((await buildService().performSync()).isSuccess, isTrue);
      expect(await notesOf('d1'), 'from A', reason: 'A kept it');
    },
  );
}
