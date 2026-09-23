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

/// Adopt applies rows straight through the upsert, which builds with
/// nullToAbsent, so a cleared stamp in the library being adopted used to
/// leave this device's own value in place: the adopted library was not the
/// one the cloud held. The merge path lands those clears with a targeted
/// write; adopt needs the same one (media sync program spec 5.1).
void main() {
  late AppDatabase db;
  late String id;

  Future<Object?> uploadedAt() async =>
      (await db
              .customSelect(
                'SELECT remote_uploaded_at FROM media WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .data
          .values
          .first;

  SyncPayload payload(Map<String, dynamic> row, int exportedAt) => SyncPayload(
    version: 1,
    exportedAt: exportedAt,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(media: [row]),
    deletions: const {},
  );

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
    // This device believes the object is uploaded.
    await MediaRepository().stampRemoteUploaded(
      id,
      uploadedAt: DateTime(2026, 8),
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('an adopted clear lands over this device\'s stamp', () async {
    final row = (await SyncDataSerializer().fetchRecord('media', id))!;
    // The library being adopted says the object is not uploaded.
    final cleared = {
      ...row,
      'remoteUploadedAt': null,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugAdoptInMemory([payload(cleared, 1)]);

    expect(
      await uploadedAt(),
      isNull,
      reason: 'the adopted library is the one the cloud holds',
    );
  });

  test('a later payload clears what an earlier one set', () async {
    final row = (await SyncDataSerializer().fetchRecord('media', id))!;
    final set = {
      ...row,
      'remoteUploadedAt': DateTime(2026, 9).millisecondsSinceEpoch,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };
    final cleared = {
      ...row,
      'remoteUploadedAt': null,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };

    // Sequence order is the resolution during a wholesale replace.
    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugAdoptInMemory([payload(set, 1), payload(cleared, 2)]);

    expect(await uploadedAt(), isNull);
  });

  group('an adopted null fact clock', () {
    // The v224 backstop adds the fact clock columns without backfilling, so
    // a library that upgraded that way publishes rows carrying a null clock
    // beside non-null facts. A null clock means "fall back to the row
    // clock", so it has to land. The two adopt paths differ on whether it
    // does by itself: the in-memory one writes the data class directly and
    // so writes nulls, the streaming one batches through nullToAbsent.
    test(
      'survives the batched upsert, which is why the write is needed',
      () async {
        final row = (await SyncDataSerializer().fetchRecord('media', id))!;
        final before = row['uploadFactsHlc'];
        expect(before, isNotNull);

        await SyncDataSerializer().upsertRecords('media', [
          {...row, 'uploadFactsHlc': null},
        ]);

        final after = await db
            .customSelect(
              'SELECT upload_facts_hlc FROM media WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle();
        expect(
          after.data.values.first,
          before,
          reason:
              'the batched arm drops it, so the adopt needs the targeted '
              'write to land a null clock',
        );
      },
    );

    test('is cleared by the targeted write', () async {
      final row = (await SyncDataSerializer().fetchRecord('media', id))!;

      await SyncDataSerializer().writeFactGroup(
        'media',
        id,
        SyncFactGroups.mediaUpload,
        {...row, 'uploadFactsHlc': null},
      );

      final after = await db
          .customSelect(
            'SELECT upload_facts_hlc FROM media WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      expect(after.data.values.first, isNull);
    });
  });

  test('a row that clears nothing keeps its adopted value', () async {
    final row = (await SyncDataSerializer().fetchRecord('media', id))!;
    final moved = {
      ...row,
      'remoteUploadedAt': DateTime(2026, 9).millisecondsSinceEpoch,
      'uploadFactsHlc': SyncClock.instance.issue(),
    };

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugAdoptInMemory([payload(moved, 1)]);

    expect(await uploadedAt(), DateTime(2026, 9).millisecondsSinceEpoch);
  });
}
