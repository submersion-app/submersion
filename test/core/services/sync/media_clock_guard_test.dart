import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The media tables merged as blind upserts: the last copy to arrive owned
/// the whole row, so a peer's older snapshot overwrote a newer local edit.
/// They now refuse a copy strictly older than the local row, as the
/// parent-gated children do; a tie or a missing clock still applies.
void main() {
  late AppDatabase db;
  late String id;

  SyncPayload payloadWith(List<Map<String, dynamic>> media) => SyncPayload(
    version: 1,
    exportedAt: 0,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(media: media),
    deletions: const {},
  );

  Future<void> apply(Map<String, dynamic> row) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  ).debugApplyPayload(payloadWith([row]));

  Future<String?> captionOf() async =>
      (await db
              .customSelect(
                'SELECT caption FROM media WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String?>('caption');

  /// A local caption edit, published: the guard must hold without the
  /// pending rule's help.
  Future<void> captionLocally(String caption) async {
    await db.customStatement('UPDATE media SET caption = ? WHERE id = ?', [
      caption,
      id,
    ]);
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: id,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await SyncRepository().clearPendingRecords();
  }

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
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('every clocked blind-upsert entity is guarded', () {
    // A blind-upsert entity that carries its own clock must be guarded, or
    // its local row is never fetched: the stale-copy check cannot run and a
    // pending row still skips the peer's copy (media sync program spec 5.1).
    final unguarded = [
      for (final entry in SyncService.entityHasUpdatedAt.entries)
        if (!entry.value &&
            SyncRepository.hlcTargets.containsKey(entry.key) &&
            !SyncDataSerializer.parentGatedChildEntities.contains(entry.key) &&
            !SyncDataSerializer.clockGuardedEntities.contains(entry.key))
          entry.key,
    ];
    expect(
      unguarded,
      isEmpty,
      reason: 'add each to SyncDataSerializer.clockGuardedEntities',
    );
  });

  test('every clock-guarded entity has a batched fetch', () async {
    // The merge fetches local rows for every guarded entity; without an arm
    // in fetchRecords each row costs its own SELECT.
    for (final type in SyncDataSerializer.clockGuardedEntities) {
      final rows = await SyncDataSerializer().fetchRecords(type, const []);
      expect(rows, isEmpty, reason: type);
    }
  });

  test('every clock-guarded entity is a stamped HLC target', () {
    for (final type in SyncDataSerializer.clockGuardedEntities) {
      expect(SyncRepository.hlcTargets[type], isNotNull, reason: type);
      expect(
        SyncDataSerializer.parentGatedChildEntities,
        isNot(contains(type)),
        reason: '$type exports on its own clock, not through a parent',
      );
    }
    expect(SyncDataSerializer.clockGuardedEntities, {
      'media',
      'mediaEnrichment',
      'mediaSpecies',
      'mediaStores',
      'species',
      'importedFiles',
      'fieldPresets',
    });
  });

  test('a strictly older copy does not overwrite a newer local edit', () async {
    final before = (await SyncDataSerializer().fetchRecord('media', id))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await captionLocally('mine');

    await apply({...before, 'caption': 'stale'});

    expect(await captionOf(), 'mine');
  });

  test('a newer copy applies', () async {
    await captionLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;
    await apply({
      ...local,
      'caption': 'theirs',
      'hlc': SyncClock.instance.issue(),
    });
    expect(await captionOf(), 'theirs');
  });

  test('a copy with no clock still applies, as the blind upsert did', () async {
    await captionLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;
    await apply({...local, 'caption': 'legacy peer'}..remove('hlc'));
    expect(await captionOf(), 'legacy peer');
  });

  test('the batched fetch serves media rows', () async {
    final rows = await SyncDataSerializer().fetchRecords('media', [id, 'none']);
    expect(rows.keys, [id]);
    expect(rows[id]!['hlc'], isNotNull);
  });
}
