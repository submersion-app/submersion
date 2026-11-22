import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';

import '../../../features/species_id/data/identification_fixtures.dart';
import '../../../helpers/test_database.dart';

/// Marine life results sync (issue #4876): runs, identifications and the
/// crops of named ones travel as clock-guarded entities, and the diver's
/// decisions merge under their own clock.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;
  late MediaIdentificationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    repo = MediaIdentificationRepository(database: db);
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  Future<void> apply(SyncData data) =>
      SyncService(
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

  Future<void> storeVideo() => repo.storeRun(
    run(mediaId: 'v1').copyWith(
      scannedMs: () => 4000,
      videoDurationMs: () => 9000,
      scannedRanges: () => ScannedRanges.prefix(4000),
      analysedBy: () => 'laptop',
      runId: () => 'r1',
    ),
    insert: [track('t1').copyWith(runId: () => 'r1')],
    deleteIds: const [],
  );

  final jpeg = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]);

  Future<void> storeCrop() => db
      .into(db.mediaIdentificationCrops)
      .insert(
        MediaIdentificationCropsCompanion.insert(
          id: 't1',
          mediaId: 'v1',
          jpeg: jpeg,
        ),
      );

  group('registration', () {
    const types = [
      'mediaIdentificationRuns',
      'mediaIdentifications',
      'mediaIdentificationCrops',
    ];

    test('the three are clock-guarded children of media', () {
      for (final type in types) {
        expect(SyncDataSerializer.clockGuardedEntities, contains(type));
        expect(SyncService.entityHasUpdatedAt[type], isFalse, reason: type);
        expect(
          SyncService.parentRefs[type]!.map(
            (r) => '${r.field}:${r.parent}:${r.nullable}',
          ),
          ['mediaId:media:false'],
          reason: type,
        );
      }
      expect(
        SyncRepository.hlcTargets['mediaIdentificationRuns']!.pk,
        'media_id',
      );
      expect(SyncRepository.hlcTargets['mediaIdentificationCrops']!.pk, 'id');
    });

    test('decisions are a fact group that is unset when null', () {
      const group = SyncFactGroups.identificationDecision;
      expect(SyncFactGroups.of('mediaIdentifications'), [group]);
      expect(group.clockColumn, 'decision_hlc');
      expect(group.nullClockIsUnset, isTrue);
      expect(group.columns.keys, {
        'decision',
        'decidedSpeciesId',
        'decidedAt',
        'claimedSpeciesId',
      });
    });
  });

  test('each entity round-trips through fetch, upsert and delete, '
      'blobs included', () async {
    await storeVideo();
    await storeCrop();
    final runJson = (await serializer.fetchRecord(
      'mediaIdentificationRuns',
      'v1',
    ))!;
    final rowJson = (await serializer.fetchRecord(
      'mediaIdentifications',
      't1',
    ))!;
    final cropJson = (await serializer.fetchRecord(
      'mediaIdentificationCrops',
      't1',
    ))!;
    // Through JSON, as the wire carries them.
    final runWire = jsonDecode(jsonEncode(runJson)) as Map<String, dynamic>;
    final rowWire = jsonDecode(jsonEncode(rowJson)) as Map<String, dynamic>;
    final cropWire = jsonDecode(jsonEncode(cropJson)) as Map<String, dynamic>;

    // The path as stored: the codec quantises it.
    final storedPath = (await repo.forMedia('v1')).single.path;
    await serializer.deleteRecord('mediaIdentificationCrops', 't1');
    await serializer.deleteRecord('mediaIdentifications', 't1');
    await serializer.deleteRecord('mediaIdentificationRuns', 'v1');
    expect(await repo.runFor('v1'), isNull);
    expect(await repo.forMedia('v1'), isEmpty);

    await serializer.upsertRecord('mediaIdentificationRuns', runWire);
    await serializer.upsertRecords('mediaIdentifications', [rowWire]);
    await serializer.upsertRecord('mediaIdentificationCrops', cropWire);
    final back = (await repo.runFor('v1'))!;
    expect(back.scanned, ScannedRanges.prefix(4000));
    expect(back.analysedBy, 'laptop');
    expect(back.runId, 'r1');
    expect((await repo.forMedia('v1')).single.path, storedPath);
    final crop = await (db.select(
      db.mediaIdentificationCrops,
    )..where((c) => c.id.equals('t1'))).getSingle();
    expect(crop.jpeg, jpeg);
    expect(
      await serializer.recordIdsFor('mediaIdentificationRuns'),
      contains('v1'),
    );
    expect(
      await serializer.recordIdsFor('mediaIdentificationCrops'),
      contains('t1'),
    );
  });

  test('a full export carries all three', () async {
    await storeVideo();
    await storeCrop();
    final payload = await serializer.exportData(
      deviceId: 'dev',
      deletions: const [],
    );
    final back = SyncData.fromJson(
      jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
    );
    expect(back.mediaIdentificationRuns.single['mediaId'], 'v1');
    expect(back.mediaIdentifications.single['id'], 't1');
    expect(back.mediaIdentificationCrops.single['id'], 't1');
  });

  group('the backfill', () {
    test('stamps a run from before v381 with this device before it '
        'publishes, and leaves a stamped one alone', () async {
      await repo.storeRun(run(), insert: const [], deleteIds: const []);
      await repo.storeRun(
        run(mediaId: 'm2').copyWith(analysedBy: () => 'laptop'),
        insert: const [],
        deleteIds: const [],
      );
      await SyncRepository().backfillMissingHlc();
      final me = await SyncRepository().getDeviceId();
      expect((await repo.runFor('m1'))!.analysedBy, me);
      expect((await repo.runFor('m2'))!.analysedBy, 'laptop');
      final hlc = await db
          .customSelect(
            "SELECT hlc FROM media_identification_runs WHERE media_id = 'm1'",
          )
          .getSingle();
      expect(hlc.read<String?>('hlc'), isNotNull);
    });
  });

  group('decisions merge under their own clock (Review Focus 3)', () {
    Future<Map<String, dynamic>> localRow() async =>
        (await serializer.fetchRecord('mediaIdentifications', 'a'))!;

    Future<void> decideLocally() async {
      await repo.storeRun(
        run(),
        insert: [identification('a')],
        deleteIds: const [],
      );
      await SyncRepository().markRecordPending(
        entityType: 'mediaIdentifications',
        recordId: 'a',
        localUpdatedAt: 1,
      );
      await repo.updateDecisions([
        identification(
          'a',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp1',
        ),
      ]);
      await SyncRepository().markFactsPending(
        entityType: 'mediaIdentifications',
        recordId: 'a',
        localUpdatedAt: 2,
        group: SyncFactGroups.identificationDecision,
      );
      await SyncRepository().clearPendingRecords();
    }

    test('a newer machine rewrite from a peer that never saw the accept '
        'keeps the accept and takes the new scores', () async {
      await decideLocally();
      final mine = await localRow();
      // The peer renamed the row after this device's accept, from a copy
      // made before it: its row clock is newer, its decision fields old.
      await apply(
        SyncData(
          mediaIdentifications: [
            {
              ...mine,
              'openScore': 0.91,
              'decision': 'undecided',
              'decidedSpeciesId': null,
              'decidedAt': null,
              'decisionHlc': null,
              'hlc': SyncClock.instance.issue(),
            },
          ],
        ),
      );
      final row = (await repo.forMedia('m1')).single;
      expect(row.openScore, 0.91);
      expect(row.decision, IdentificationDecision.accepted);
      expect(row.decidedSpeciesId, 'sp1');
    });

    test(
      'a newer decision from a peer wins, a cleared claim included',
      () async {
        await decideLocally();
        await repo.claim('a', 'sp2');
        await SyncRepository().markFactsPending(
          entityType: 'mediaIdentifications',
          recordId: 'a',
          localUpdatedAt: 3,
          group: SyncFactGroups.identificationDecision,
        );
        final mine = await localRow();
        // The peer undid the accept and withdrew the claim, later.
        await apply(
          SyncData(
            mediaIdentifications: [
              {
                ...mine,
                'decision': 'undecided',
                'decidedSpeciesId': null,
                'claimedSpeciesId': null,
                'decisionHlc': SyncClock.instance.issue(),
              },
            ],
          ),
        );
        final row = (await repo.forMedia('m1')).single;
        expect(row.decision, IdentificationDecision.undecided);
        expect(row.claimedSpeciesId, isNull);
      },
    );

    test('an older decision from a peer loses', () async {
      final early = SyncClock.instance.issue();
      await decideLocally();
      final mine = await localRow();
      await apply(
        SyncData(
          mediaIdentifications: [
            {
              ...mine,
              'decision': 'rejected',
              'decisionHlc': early,
              'hlc': SyncClock.instance.issue(),
            },
          ],
        ),
      );
      expect(
        (await repo.forMedia('m1')).single.decision,
        IdentificationDecision.accepted,
      );
    });
  });
}
