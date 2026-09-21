import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// A peer's cleared upload stamp arrives as an explicit null, which the row
/// upsert cannot carry (it builds with nullToAbsent), so a targeted fact
/// write follows it. If that write fails and the failure is swallowed, the
/// row keeps the peer's NEW fact clock over this device's OLD values, the
/// reader advances its cursor past the changeset, and the clear is lost for
/// good. The apply must fail instead, so the payload rolls back.
void main() {
  late AppDatabase db;
  late String id;

  Future<Map<String, Object?>> uploadFacts() async =>
      (await db
              .customSelect(
                'SELECT remote_uploaded_at, upload_facts_hlc FROM media '
                'WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .data;

  setUp(() async {
    db = await setUpTestDatabase();
    id = (await MediaRepository().createMedia(
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
    await MediaRepository().stampRemoteUploaded(
      id,
      uploadedAt: DateTime(2026, 8),
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a failed fact write rolls the payload back', () async {
    final before = await uploadFacts();
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;

    // The peer cleared the stamp and its upload clock is newer.
    final cleared = {
      ...local,
      'remoteUploadedAt': null,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };

    await expectLater(
      SyncService(
        syncRepository: SyncRepository(),
        serializer: _FailingFactWriter(),
      ).debugApplyPayload(
        SyncPayload(
          version: 1,
          exportedAt: 0,
          deviceId: 'peer',
          checksum: '',
          data: SyncData(media: [cleared]),
          deletions: const {},
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await uploadFacts(),
      before,
      reason:
          'the row upsert rolled back with the fact write, so the '
          "peer's clear is still outstanding and re-applies next sync",
    );
  });

  test('a failed batch upsert takes its own fact writes with it', () async {
    // The batch is all-or-nothing, so its failure means the row was never
    // written. Applying the fact write anyway would land half a changeset
    // that failed: the row keeps its old values while its fact columns and
    // clock move, which consumes the peer's clear outright.
    final before = await uploadFacts();
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;

    final cleared = {
      ...local,
      'remoteUploadedAt': null,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: _FailingBatchUpsert(),
    ).debugApplyPayload(
      SyncPayload(
        version: 1,
        exportedAt: 0,
        deviceId: 'peer',
        checksum: '',
        data: SyncData(media: [cleared]),
        deletions: const {},
      ),
    );

    expect(
      await uploadFacts(),
      before,
      reason: 'neither half of the change landed',
    );
  });
}

/// Every targeted fact write fails, as a disk error or a locked database
/// would make it.
class _FailingFactWriter extends SyncDataSerializer {
  @override
  Future<void> writeFactGroup(
    String entityType,
    String recordId,
    SyncFactGroup group,
    Map<String, dynamic> values,
  ) async => throw StateError('fact write failed');
}

/// The batched row upsert fails, as a constraint violation or a malformed
/// row would make it. Drift's batch is all-or-nothing, so nothing lands.
class _FailingBatchUpsert extends SyncDataSerializer {
  @override
  Future<void> upsertRecords(
    String entityType,
    List<Map<String, dynamic>> records,
  ) async => throw StateError('batch upsert failed');
}
