import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'identification_fixtures.dart';
import 'media_identification_service_fixtures.dart';

/// Which analysis made a run, and who (issue #4876): a run id minted when
/// an analysis starts and kept by every later chunk of a video, and this
/// device as its maker.
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late MediaIdentificationRepository identifications;
  late FakeEngine engine;
  late MediaIdentificationService service;
  var ids = 0;
  var runs = 0;

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_sync');
    identifications = MediaIdentificationRepository(database: library);
    engine = FakeEngine();
    ids = 0;
    runs = 0;
    service = MediaIdentificationService(
      engine: engine,
      loadPack: () async => pack(),
      identifications: identifications,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(
        supportPath: () async => support.path,
        table: IdentificationCropRepository(database: library),
      ),
      resolveImage: (item) async =>
          IdentificationImage.path('/photos/${item.id}.jpeg'),
      resolveVideo: (item) async =>
          <T>(Future<T> Function(String path) read) =>
              read('/videos/${item.id}.mp4'),
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
      now: () => DateTime.utc(2026, 11, 17),
      newId: () => 'id-${ids++}',
      newRunId: () => 'run-${runs++}',
      deviceId: () async => 'phone',
      idleUnload: const Duration(milliseconds: 50),
      firstVideoChunkMs: 10000,
    );
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  test('a photo analysis records this device and a fresh run id, shared by '
      'its rows', () async {
    await service.request(photo('m1'));
    final stored = (await identifications.runFor('m1'))!;
    expect(stored.analysedBy, 'phone');
    expect(stored.runId, 'run-0');
    final rows = await identifications.forMedia('m1');
    expect(rows, isNotEmpty);
    expect(rows.map((i) => i.runId).toSet(), {'run-0'});
    expect(
      stored.namingBars,
      NamingBars.fromNaming(pack().pack.manifest.naming),
      reason: 'a device with no pack names its rows by them',
    );
  });

  test('a named fish\'s crop is kept in the logbook (issue #4876)', () async {
    await service.request(photo('m1'));
    final table = IdentificationCropRepository(database: library);
    final rows = await identifications.forMedia('m1');
    final named = [
      for (final i in rows)
        if (isNamed(i)) i.id,
    ];
    expect(named, isNotEmpty);
    expect(await table.presentAmong(named), named.toSet());
  });

  test(
    'analysing again starts a new run, and the rows of the old one go',
    () async {
      await service.request(photo('m1'));
      await service.request(photo('m1'), fresh: true);
      expect((await identifications.runFor('m1'))!.runId, 'run-1');
      expect(
        (await identifications.forMedia('m1')).map((i) => i.runId).toSet(),
        {'run-1'},
      );
    },
  );

  test('a video scanned in three chunks keeps one run id on every track '
      '(Review Focus 2)', () async {
    // One fish in the first chunk, another in the third.
    engine.videoFrames = {
      for (var ms = 1000; ms < 4000; ms += 250)
        ms: [
          const DetectedBox(
            box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
            score: 0.9,
          ),
        ],
      for (var ms = 21000; ms < 24000; ms += 250)
        ms: [
          const DetectedBox(
            box: IdentificationBox(x: 0.6, y: 0.2, width: 0.2, height: 0.1),
            score: 0.9,
          ),
        ],
    };
    await service.request(photo('v1', type: MediaType.video));
    expect(engine.detectCalls, hasLength(3));
    final stored = (await identifications.runFor('v1'))!;
    expect(stored.runId, 'run-0');
    expect(stored.analysedBy, 'phone');
    final tracks = await identifications.forMedia('v1');
    expect(tracks, hasLength(2));
    expect(tracks.map((i) => i.runId).toSet(), {'run-0'});
    expect(visibleRows(stored, tracks), hasLength(2));
  });

  test('on the device that made the run, a leftover of a run that lost a '
      'sync race goes when the photo opens, with no analysis again', () async {
    await service.request(photo('m1'));
    final analyses = engine.analysed.length;
    // The laptop analysed the same photo before syncing; its rows arrive
    // and are hidden under this device's run.
    await identifications.storeRun(
      (await identifications.runFor('m1'))!,
      insert: [
        identification(
          'laptop-row',
          mediaId: 'm1',
        ).copyWith(runId: () => 'laptop-run'),
      ],
      deleteIds: const [],
    );

    await service.request(photo('m1'));

    expect(engine.analysed, hasLength(analyses));
    expect((await identifications.runFor('m1'))!.runId, 'run-0');
    expect([
      for (final i in await identifications.forMedia('m1')) i.id,
    ], isNot(contains('laptop-row')));
  });

  group('a run another device made (Review Focus 1)', () {
    Future<void> storeElsewhere(String mediaId, {int? scannedMs}) =>
        identifications.storeRun(
          run(mediaId: mediaId).copyWith(
            packVersion: pack().pack.manifest.packVersion,
            analysedBy: () => 'laptop',
            runId: () => 'laptop-run',
            scannedMs: () => scannedMs,
            videoDurationMs: () => scannedMs == null ? null : 25000,
          ),
          insert: [identification('i-$mediaId', mediaId: mediaId)],
          deleteIds: const [],
        );

    test(
      'is left alone on opening, its crops and embeddings missing',
      () async {
        await storeElsewhere('m1');
        await service.request(photo('m1'));
        expect(engine.analysed, isEmpty);
        expect((await identifications.runFor('m1'))!.analysedBy, 'laptop');
        expect((await identifications.forMedia('m1')).single.id, 'i-m1');
      },
    );

    test('is analysed here when the diver asks again', () async {
      await storeElsewhere('m1');
      await service.request(photo('m1'), fresh: true);
      expect(engine.analysed, isNotEmpty);
      expect((await identifications.runFor('m1'))!.analysedBy, 'phone');
    });

    test('a video it scanned part-way is not resumed here', () async {
      await storeElsewhere('v1', scannedMs: 10000);
      await service.request(photo('v1', type: MediaType.video));
      expect(engine.detectCalls, isEmpty);
    });
  });
}
