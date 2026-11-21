import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../data/fake_vision_engine.dart';
import '../data/identification_fixtures.dart';
import '../domain/manifest_fixture.dart';

/// The labels mode preference, and what the viewer reads to draw labels,
/// the scrub bar's analysed stretches and the menu's status (issue #4825).
void main() {
  late AppDatabase db;
  late Directory support;
  late MediaIdentificationRepository repository;
  late IdentificationCropStore crops;
  late InstalledPack? installed;
  late ProviderContainer container;

  final manifest = SpeciesPackManifest.parse(manifestJson());

  MediaItem item(String id, {MediaType type = MediaType.photo}) => MediaItem(
    id: id,
    mediaType: type,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  /// A run the installed pack would leave as it is.
  MediaIdentificationRun currentRun(String mediaId, {bool video = false}) =>
      MediaIdentificationRun(
        mediaId: mediaId,
        packVersion: manifest.packVersion,
        detectorId: video
            ? videoRunDetectorId(manifest.detectorSetId)
            : manifest.detectorSetId,
        classifierId: manifest.classifier.embeddingId,
        analysedAt: fixtureT0,
        imageWidth: 4000,
        imageHeight: 3000,
        detectionCount: 0,
      );

  setUp(() async {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    support = await Directory.systemTemp.createTemp('label_providers');
    repository = MediaIdentificationRepository(database: db);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    installed = InstalledPack(
      manifest: manifest,
      directory: '/pack',
      detectorPaths: const ['/pack/detector.mlpackage'],
      classifierPath: '/pack/classifier.mlpackage',
    );
    final service = MediaIdentificationService(
      engine: FakeEngine(),
      loadPack: () async => null,
      identifications: repository,
      embeddings: IdentificationEmbeddingRepository(),
      crops: crops,
      resolveImage: (_) async => null,
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
    );
    addTearDown(service.dispose);
    container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(repository),
        identificationCropStoreProvider.overrideWithValue(crops),
        mediaIdentificationServiceProvider.overrideWithValue(service),
        installedSpeciesPackProvider.overrideWith((ref) async => installed),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await deleteTempDir(support);
  });

  group('the labels mode', () {
    test('is names until one is chosen, and is stored when changed', () async {
      expect(container.read(labelModeProvider), LabelMode.names);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = LabelModeNotifier(prefs);
      addTearDown(notifier.dispose);
      expect(notifier.state, LabelMode.names);

      await notifier.setMode(LabelMode.allLife);
      expect(notifier.state, LabelMode.allLife);
      expect(prefs.getString('species_id_label_mode'), 'allLife');

      final again = LabelModeNotifier(prefs);
      addTearDown(again.dispose);
      expect(again.state, LabelMode.allLife);
    });

    test('a stored mode this version does not know reads as names', () async {
      SharedPreferences.setMockInitialValues({
        'species_id_label_mode': 'later-version',
      });
      final notifier = LabelModeNotifier(await SharedPreferences.getInstance());
      addTearDown(notifier.dispose);
      expect(notifier.state, LabelMode.names);
    });

    test('with nothing behind it, a change is kept for the session', () async {
      final notifier = LabelModeNotifier.unstored(LabelMode.off);
      addTearDown(notifier.dispose);
      expect(notifier.state, LabelMode.off);
      await notifier.setMode(LabelMode.names);
      expect(notifier.state, LabelMode.names);
    });
  });

  group('photoDetectionsProvider', () {
    test('gives a photo\'s detections and leaves out video tracks', () async {
      await repository.storeRun(
        run(mediaId: 'm1'),
        insert: [
          identification('p', mediaId: 'm1'),
          track('t', mediaId: 'm1'),
        ],
        deleteIds: const [],
      );
      final found = await container.read(photoDetectionsProvider('m1').future);
      expect(found.map((i) => i.id), ['p']);
    });

    test('is empty with the feature off', () async {
      marineLifeIdEnabled = false;
      await repository.storeRun(
        run(mediaId: 'm1'),
        insert: [identification('p', mediaId: 'm1')],
        deleteIds: const [],
      );
      expect(
        await container.read(photoDetectionsProvider('m1').future),
        isEmpty,
      );
    });

    test('follows a new analysis', () async {
      final sub = container.listen(photoDetectionsProvider('m1'), (_, _) {});
      addTearDown(sub.close);
      expect(
        await container.read(photoDetectionsProvider('m1').future),
        isEmpty,
      );
      await repository.storeRun(
        run(mediaId: 'm1'),
        insert: [identification('p', mediaId: 'm1')],
        deleteIds: const [],
      );
      await pumpEventQueue();
      expect(
        await container.read(photoDetectionsProvider('m1').future),
        hasLength(1),
      );
    });
  });

  group('videoScanStretchesProvider', () {
    Future<void> store(ScannedRanges scanned, {int? durationMs = 25000}) =>
        repository.storeRun(
          videoRun(
            scannedMs: null,
            videoDurationMs: durationMs,
          ).copyWith(scannedRanges: () => scanned),
          insert: const [],
          deleteIds: const [],
        );

    test('gives the stretches of a scan that is not finished', () async {
      await store(
        ScannedRanges.of([
          (startMs: 0, endMs: 8000),
          (startMs: 15000, endMs: 20000),
        ]),
      );
      final stretches = await container.read(
        videoScanStretchesProvider('v1').future,
      );
      expect(stretches!.durationMs, 25000);
      expect(stretches.scanned.stretches, [
        (startMs: 0, endMs: 8000),
        (startMs: 15000, endMs: 20000),
      ]);
    });

    test('is null once the whole video is scanned', () async {
      await store(ScannedRanges.prefix(25000));
      expect(
        await container.read(videoScanStretchesProvider('v1').future),
        isNull,
      );
    });

    test('is null for a video never scanned, or whose length is not known '
        'yet', () async {
      expect(
        await container.read(videoScanStretchesProvider('v1').future),
        isNull,
      );
      await store(ScannedRanges.prefix(2000), durationMs: null);
      container.invalidate(videoScanStretchesProvider('v1'));
      expect(
        await container.read(videoScanStretchesProvider('v1').future),
        isNull,
      );
    });

    test('is null with the feature off', () async {
      marineLifeIdEnabled = false;
      await store(ScannedRanges.prefix(8000));
      expect(
        await container.read(videoScanStretchesProvider('v1').future),
        isNull,
      );
    });
  });

  group('mediaAnalysisStatusProvider', () {
    Future<MediaAnalysisStatus> status(MediaItem item, {GeoPoint? at}) =>
        container.read(
          mediaAnalysisStatusProvider(AnalysisTarget(item, at)).future,
        );

    test('no model, with what an earlier one found still counted', () async {
      installed = null;
      await repository.storeRun(
        currentRun('m1'),
        insert: [identification('a', mediaId: 'm1')],
        deleteIds: const [],
      );
      final s = await status(item('m1'));
      expect(s.state, MediaAnalysisState.noModel);
      expect(s.found, 1);
    });

    test('never analysed', () async {
      final s = await status(item('m1'));
      expect(s.state, MediaAnalysisState.notAnalysed);
      expect(s.found, 0);
    });

    test('analysed, counting what was found less what was dismissed', () async {
      await repository.storeRun(
        currentRun('m1'),
        insert: [
          identification('a', mediaId: 'm1'),
          identification(
            'b',
            mediaId: 'm1',
            decision: IdentificationDecision.rejected,
          ),
        ],
        deleteIds: const [],
      );
      await crops.write('m1', 'a', Uint8List.fromList([0xFF, 0xD8]));
      await crops.markAnalysed('m1');
      final s = await status(item('m1'));
      expect(s.state, MediaAnalysisState.analysed);
      expect(s.found, 1);
    });

    test('partial when another pack analysed it', () async {
      await repository.storeRun(
        currentRun('m1').copyWith(packVersion: 'older'),
        insert: const [],
        deleteIds: const [],
      );
      expect((await status(item('m1'))).state, MediaAnalysisState.partial);
    });

    test(
      'partial for a video part scanned, analysed once it is whole',
      () async {
        final video = item('v1', type: MediaType.video);
        await repository.storeRun(
          currentRun(
            'v1',
            video: true,
          ).copyWith(scannedMs: () => 10000, videoDurationMs: () => 25000),
          insert: const [],
          deleteIds: const [],
        );
        expect((await status(video)).state, MediaAnalysisState.partial);

        await repository.storeRun(
          currentRun(
            'v1',
            video: true,
          ).copyWith(scannedMs: () => 25000, videoDurationMs: () => 25000),
          insert: const [],
          deleteIds: const [],
        );
        container.invalidate(
          mediaAnalysisStatusProvider(AnalysisTarget(video, null)),
        );
        expect((await status(video)).state, MediaAnalysisState.analysed);
      },
    );

    test('two targets for the same item and place are one', () {
      final a = AnalysisTarget(item('m1'), const GeoPoint(12, -68));
      final b = AnalysisTarget(item('m1'), const GeoPoint(12, -68));
      expect(a, b);
      expect(a, isNot(AnalysisTarget(item('m1'), null)));
      expect(a, isNot(AnalysisTarget(item('m2'), const GeoPoint(12, -68))));
    });
  });
}
