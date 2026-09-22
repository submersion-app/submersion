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

  group('the guard covers every clock-guarded media table', () {
    // The clock-guarded set changes merge behaviour for four tables, each
    // with its own fetch and upsert arm, so a media-only test would let a
    // regression in any of the other three through.
    setUp(() async {
      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
        "VALUES ('d1', 0, 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO species (id, common_name, category) "
        "VALUES ('sp1', 'Grouper', 'fish')",
      );
      await db.customStatement(
        "INSERT INTO media_enrichment (id, media_id, dive_id, "
        "match_confidence, created_at) VALUES ('e1', ?, 'd1', 'mine', 0)",
        [id],
      );
      await db.customStatement(
        "INSERT INTO media_species (id, media_id, species_id, notes, "
        "created_at) VALUES ('ms1', ?, 'sp1', 'mine', 0)",
        [id],
      );
      await db.customStatement(
        "INSERT INTO media_stores (id, provider_type, display_hint, "
        "created_at, updated_at) VALUES ('st1', 's3', 'mine', 0, 0)",
      );
    });

    /// Stamps the row's clock the way a local edit would, then publishes it
    /// so the pending rule cannot be what refuses the peer's copy.
    Future<void> stampLocally(String entityType, String recordId) async {
      await SyncRepository().markRecordPending(
        entityType: entityType,
        recordId: recordId,
        localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await SyncRepository().clearPendingRecords();
    }

    Future<void> applyOne(String entityType, Map<String, dynamic> row) {
      final data = switch (entityType) {
        'mediaEnrichment' => SyncData(mediaEnrichment: [row]),
        'mediaSpecies' => SyncData(mediaSpecies: [row]),
        'mediaStores' => SyncData(mediaStores: [row]),
        _ => throw ArgumentError.value(entityType, 'entityType'),
      };
      return SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyPayload(
        SyncPayload(
          version: 1,
          exportedAt: 0,
          deviceId: 'peer',
          checksum: '',
          data: data,
          deletions: const {},
        ),
      );
    }

    Future<String?> readValue(String sql) async =>
        (await db.customSelect(sql).getSingle()).data.values.first as String?;

    final cases = <({String type, String id, String field, String sql})>[
      (
        type: 'mediaEnrichment',
        id: 'e1',
        field: 'matchConfidence',
        sql: "SELECT match_confidence FROM media_enrichment WHERE id = 'e1'",
      ),
      (
        type: 'mediaSpecies',
        id: 'ms1',
        field: 'notes',
        sql: "SELECT notes FROM media_species WHERE id = 'ms1'",
      ),
      (
        type: 'mediaStores',
        id: 'st1',
        field: 'displayHint',
        sql: "SELECT display_hint FROM media_stores WHERE id = 'st1'",
      ),
    ];

    for (final c in cases) {
      test('${c.type} refuses a strictly older copy', () async {
        await stampLocally(c.type, c.id);
        final theirs = (await SyncDataSerializer().fetchRecord(c.type, c.id))!;
        // The local row moves on after the peer took its snapshot.
        await stampLocally(c.type, c.id);

        await applyOne(c.type, {...theirs, c.field: 'theirs'});

        expect(await readValue(c.sql), 'mine', reason: c.type);
      });

      test('${c.type} applies a strictly newer copy', () async {
        await stampLocally(c.type, c.id);
        final local = (await SyncDataSerializer().fetchRecord(c.type, c.id))!;

        await applyOne(c.type, {
          ...local,
          c.field: 'theirs',
          'hlc': SyncClock.instance.issue(),
        });

        expect(await readValue(c.sql), 'theirs', reason: c.type);
      });
    }
  });

  group('an older peer that omits a column does not erase it', () {
    // A peer on an older schema sends no key for a column it has never
    // heard of. Winning the row decides whose values stand where both sides
    // have one; the winner's silence is not an answer.
    //
    // These arms get that for free, without the _overlayOntoLocal the LWW
    // path uses, because they build their insert with nullToAbsent: an
    // absent key is simply not written. It is the same property that stops
    // a peer's explicit clear from landing through the upsert, which is why
    // writeFactGroup exists. Pinned here because the merge reads as though
    // it were taking the peer's whole map.
    test('a winning media row keeps a column the peer omitted', () async {
      await captionLocally('mine');
      await db.customStatement(
        "UPDATE media SET original_filename = 'reef.jpg' WHERE id = ?",
        [id],
      );
      final local = (await SyncDataSerializer().fetchRecord('media', id))!;

      // The peer's row is newer, changes a column it does know, and
      // predates the one it omits.
      final older = {
        ...local,
        'caption': 'theirs',
        'hlc': SyncClock.instance.issue(),
      }..remove('originalFilename');
      await apply(older);

      expect(await captionOf(), 'theirs', reason: 'the peer row did win');

      final after =
          (await db
                  .customSelect(
                    'SELECT original_filename FROM media WHERE id = ?',
                    variables: [Variable.withString(id)],
                  )
                  .getSingle())
              .read<String?>('original_filename');
      expect(after, 'reef.jpg');
    });

    test('a guarded child with no fact groups keeps it too', () async {
      await db.customStatement(
        "INSERT INTO species (id, common_name, scientific_name, category) "
        "VALUES ('sp1', 'Grouper', 'Epinephelus', 'fish')",
      );
      await SyncRepository().markRecordPending(
        entityType: 'species',
        recordId: 'sp1',
        localUpdatedAt: 0,
      );
      await SyncRepository().clearPendingRecords();
      final local = (await SyncDataSerializer().fetchRecord('species', 'sp1'))!;

      final older = {
        ...local,
        'commonName': 'Snapper',
        'hlc': SyncClock.instance.issue(),
      }..remove('scientificName');
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyPayload(
        SyncPayload(
          version: 1,
          exportedAt: 0,
          deviceId: 'peer',
          checksum: '',
          data: SyncData(species: [older]),
          deletions: const {},
        ),
      );

      final after = await db
          .customSelect(
            'SELECT common_name, scientific_name FROM species '
            "WHERE id = 'sp1'",
          )
          .getSingle();
      expect(
        after.read<String?>('common_name'),
        'Snapper',
        reason: 'the peer row did win',
      );
      expect(after.read<String?>('scientific_name'), 'Epinephelus');
    });
  });

  test('a fact-only pending row still takes the peer\'s facts', () async {
    // A media row's first local write can be a fact write, which stamps the
    // group clock and leaves the row clock null. The row is then pending
    // and unorderable, and skipping it outright threw the peer's facts
    // away for good, because the reader advances its cursor regardless.
    await db.customStatement('UPDATE media SET hlc = NULL WHERE id = ?', [id]);
    await MediaRepository().stampRemoteUploaded(
      id,
      uploadedAt: DateTime(2026, 8),
    );
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;
    expect(local['hlc'], isNull, reason: 'a fact write leaves the row clock');

    // The peer has a newer verification fact and its own row clock.
    await apply({
      ...local,
      'caption': 'theirs',
      'hlc': SyncClock.instance.issue(),
      'isOrphaned': true,
      'verifyFactsHlc': SyncClock.instance.issue(),
    });

    final row = await db
        .customSelect(
          'SELECT caption, is_orphaned FROM media WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    expect(
      row.read<int>('is_orphaned'),
      1,
      reason: "the peer's verification fact is ordered and wins",
    );
    expect(
      row.read<String?>('caption'),
      isNot('theirs'),
      reason: 'the unpublished local row is still protected',
    );
  });

  test('a local edit after a peer delete survives the tombstone', () async {
    // The media tables joined the stale-copy guard through their own set,
    // and the deletion path was left comparing them by updatedAt.
    // mediaSpecies has no such column, so a row edited here after a peer
    // deleted it was ageless and deleted as stale.
    await db.customStatement(
      "INSERT INTO species (id, common_name, category) "
      "VALUES ('sp1', 'Grouper', 'fish')",
    );
    await db.customStatement(
      'INSERT INTO media_species (id, media_id, species_id, notes, '
      "created_at) VALUES ('ms1', ?, 'sp1', 'mine', 0)",
      [id],
    );
    // The peer's delete happens first; this device edits afterwards.
    final deletedAtHlc = SyncClock.instance.issue()!;
    await SyncRepository().markRecordPending(
      entityType: 'mediaSpecies',
      recordId: 'ms1',
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await SyncRepository().clearPendingRecords();

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugApplyPayload(
      SyncPayload(
        version: 1,
        exportedAt: 0,
        deviceId: 'peer',
        checksum: '',
        data: const SyncData(),
        deletions: {
          'mediaSpecies': [
            SyncDeletion(
              id: 'ms1',
              deletedAt: DateTime.now().millisecondsSinceEpoch,
              hlc: deletedAtHlc,
            ),
          ],
        },
      ),
    );

    final rows = await db
        .customSelect("SELECT id FROM media_species WHERE id = 'ms1'")
        .get();
    expect(
      rows,
      hasLength(1),
      reason: 'the local edit is newer than the delete that reached us',
    );
  });

  test('a fact write newer than a delete keeps the row', () async {
    // A media fact write advances ONLY its group clock and leaves the row
    // clock alone, so reading the row clock by itself makes a fresh fact
    // look older than it is. The tombstone decision then fell through to
    // the updatedAt comparison and could apply a stale delete over it.
    final deleteHlc = SyncClock.instance.issue()!;
    // The fact write happens after the peer issued its delete.
    await MediaRepository().stampRemoteUploaded(
      id,
      uploadedAt: DateTime(2026, 8),
    );
    // Published, so the pending guard above the clock comparison does not
    // stand in for it: this test is about the clocks.
    await SyncRepository().clearPendingRecords();

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugApplyPayload(
      SyncPayload(
        version: 1,
        exportedAt: 0,
        deviceId: 'peer',
        checksum: '',
        data: const SyncData(),
        deletions: {
          'media': [
            SyncDeletion(
              id: id,
              deletedAt: DateTime.now().millisecondsSinceEpoch,
              hlc: deleteHlc,
            ),
          ],
        },
      ),
    );

    final rows = await db
        .customSelect(
          'SELECT id FROM media WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    expect(
      rows,
      hasLength(1),
      reason: 'the fact write is newer than the delete that reached us',
    );
  });

  test('the batched fetch serves media rows', () async {
    final rows = await SyncDataSerializer().fetchRecords('media', [id, 'none']);
    expect(rows.keys, [id]);
    expect(rows[id]!['hlc'], isNotNull);
  });
}
