import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/video_crop_capper.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/test_database.dart';
import 'identification_fixtures.dart';

/// Applying the video crop cap (issue #5032).
void main() {
  late Directory support;
  late IdentificationCropRepository table;
  late IdentificationCropStore store;
  late MediaIdentificationRepository identifications;
  late String? me;
  final sync = SyncRepository();
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 1, 2, 0xFF, 0xD9]);

  setUp(() async {
    await setUpTestDatabase();
    support = await Directory.systemTemp.createTemp('video_crop_cap');
    table = IdentificationCropRepository();
    store = IdentificationCropStore(
      supportPath: () async => support.path,
      table: table,
    );
    identifications = MediaIdentificationRepository();
    me = 'me';
  });
  tearDown(() async {
    await store.dispose();
    await deleteTempDir(support);
    await tearDownTestDatabase();
  });

  VideoCropCapper capper() => VideoCropCapper(
    identifications: identifications,
    crops: store,
    taggedSpecies: (_) async => const [],
    deviceId: () async => me,
  );

  /// [count] accepted parrotfish tracks on [mediaId], largest first, each
  /// with a synced crop, under a run made by [madeBy].
  Future<List<String>> seedNamed(
    String mediaId,
    int count, {
    String? madeBy,
  }) async {
    final rows = [
      for (var k = 0; k < count; k++)
        track(
          '$mediaId-n$k',
          mediaId: mediaId,
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_queen_parrotfish',
        ).copyWith(boxPixelWidth: 1000 - k * 10),
    ];
    await identifications.storeRun(
      videoRun(
        mediaId: mediaId,
        count: count,
      ).copyWith(analysedBy: () => madeBy),
      insert: rows,
      deleteIds: const [],
    );
    for (final r in rows) {
      await store.write(mediaId, r.id, jpeg, named: true);
    }
    return [for (final r in rows) r.id];
  }

  Future<Set<String>> cropTombstones() async => {
    for (final d in await sync.getAllDeletions())
      if (d.entityType == 'mediaIdentificationCrops') d.recordId,
  };

  test(
    'removes the crops beyond 3 per species and tombstones the synced ones',
    () async {
      final ids = await seedNamed('v1', 5);
      expect(await capper().cap('v1'), 2);
      expect(await store.presentAmong('v1', ids), ids.take(3).toSet());
      expect(await cropTombstones(), {ids[3], ids[4]});
      expect(await identifications.forMedia('v1'), hasLength(5));
    },
  );

  test('removes unnamed file crops beyond 3', () async {
    final rows = [
      for (var k = 0; k < 5; k++)
        track(
          'u$k',
          suggestable: false,
          specific: false,
        ).copyWith(boxPixelWidth: 1000 - k * 10),
    ];
    await identifications.storeRun(
      videoRun(count: 5),
      insert: rows,
      deleteIds: const [],
    );
    for (final r in rows) {
      await store.write('v1', r.id, jpeg);
    }
    expect(await capper().cap('v1'), 2);
    expect(await store.presentAmong('v1', [for (final r in rows) r.id]), {
      'u0',
      'u1',
      'u2',
    });
  });

  test(
    'on a device that did not analyse the video it removes no synced crop',
    () async {
      final ids = await seedNamed('v1', 5, madeBy: 'other');
      expect(await capper().cap('v1'), 0);
      expect(await store.presentAmong('v1', ids), ids.toSet());
      expect(await cropTombstones(), isEmpty);
    },
  );

  test('with this device\'s id unreadable it removes no synced crop of a '
      'video another device analysed', () async {
    me = null;
    final ids = await seedNamed('v1', 5, madeBy: 'other');
    expect(await capper().cap('v1'), 0);
    expect(await store.presentAmong('v1', ids), ids.toSet());
    expect(await cropTombstones(), isEmpty);
  });

  test('with no run here for a video it removes no synced crop: the run '
      'may not have synced yet', () async {
    final ids = await seedNamed('v1', 5);
    final runless = VideoCropCapper(
      identifications: _Runless(),
      crops: store,
      taggedSpecies: (_) async => const [],
      deviceId: () async => me,
    );
    expect(await runless.cap('v1'), 0);
    expect(await store.presentAmong('v1', ids), ids.toSet());
    expect(await cropTombstones(), isEmpty);
  });

  test('a crop the rows no longer drop when it is about to go stays: a '
      'claim made meanwhile', () async {
    final ids = await seedNamed('v1', 5);
    final changing = _ClaimsAfterFirstRead(ids.last);
    final capper = VideoCropCapper(
      identifications: changing,
      crops: store,
      taggedSpecies: (_) async => const [],
      deviceId: () async => me,
    );
    expect(await capper.cap('v1'), 1);
    expect(await store.presentAmong('v1', ids), {...ids.take(3), ids.last});
  });

  test('a run another device took over between the reads removes no '
      'synced crop', () async {
    final ids = await seedNamed('v1', 5);
    final capper = VideoCropCapper(
      identifications: _TakenOverAfterFirstRead(),
      crops: store,
      taggedSpecies: (_) async => const [],
      deviceId: () async => me,
    );
    expect(await capper.cap('v1'), 0);
    expect(await store.presentAmong('v1', ids), ids.toSet());
    expect(await cropTombstones(), isEmpty);
  });

  test('does nothing for a photo', () async {
    final rows = [
      for (var k = 0; k < 5; k++)
        identification('p$k', decision: IdentificationDecision.accepted),
    ];
    await identifications.storeRun(
      run(count: 5),
      insert: rows,
      deleteIds: const [],
    );
    for (final r in rows) {
      await store.write('m1', r.id, jpeg, named: true);
    }
    expect(await capper().cap('m1'), 0);
  });

  test('is safe to run twice', () async {
    await seedNamed('v1', 5);
    expect(await capper().cap('v1'), 2);
    expect(await capper().cap('v1'), 0);
  });

  test('capAll trims every candidate video and leaves photos', () async {
    final v1 = await seedNamed('v1', 5);
    final v2 = await seedNamed('v2', 4);
    final photos = [
      for (var k = 0; k < 5; k++)
        identification('p$k', decision: IdentificationDecision.accepted),
    ];
    await identifications.storeRun(
      run(count: 5),
      insert: photos,
      deleteIds: const [],
    );
    for (final r in photos) {
      await store.write('m1', r.id, jpeg, named: true);
    }
    expect(await capper().capAll(await store.mediaWithMoreThan(3)), 3);
    expect(await store.presentAmong('v1', v1), v1.take(3).toSet());
    expect(await store.presentAmong('v2', v2), v2.take(3).toSet());
    expect(
      await store.presentAmong('m1', [for (final r in photos) r.id]),
      hasLength(5),
    );
  });
}

/// The rows of a video whose run has not arrived here.
class _Runless extends MediaIdentificationRepository {
  @override
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) async {
    final (_, rows) = await super.forMediaIdsWithRuns(
      mediaIds,
      withPaths: withPaths,
    );
    return (const <String, MediaIdentificationRun>{}, rows);
  }
}

/// Reads [claimed] as claimed from the second read on: the diver gave it
/// a species between the cap's reads.
class _ClaimsAfterFirstRead extends MediaIdentificationRepository {
  _ClaimsAfterFirstRead(this.claimed);

  final String claimed;
  var _reads = 0;

  @override
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) async {
    final (runs, rows) = await super.forMediaIdsWithRuns(
      mediaIds,
      withPaths: withPaths,
    );
    if (_reads++ == 0) return (runs, rows);
    return (
      runs,
      {
        for (final MapEntry(:key, :value) in rows.entries)
          key: [
            for (final i in value)
              i.id == claimed
                  ? i.copyWith(claimedSpeciesId: () => 'sp_grunt')
                  : i,
          ],
      },
    );
  }
}

/// Reads the run as another device's from the second read on: a sync
/// replaced it between the cap's reads.
class _TakenOverAfterFirstRead extends MediaIdentificationRepository {
  var _reads = 0;

  @override
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) async {
    final (runs, rows) = await super.forMediaIdsWithRuns(
      mediaIds,
      withPaths: withPaths,
    );
    if (_reads++ == 0) return (runs, rows);
    return (
      {
        for (final MapEntry(:key, :value) in runs.entries)
          key: value.copyWith(analysedBy: () => 'other'),
      },
      rows,
    );
  }
}
