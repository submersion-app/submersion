import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../data/identification_fixtures.dart';
import '../domain/manifest_fixture.dart';
import 'species_id_fakes.dart';

class _CountingCleanup extends IdentificationCleanup {
  _CountingCleanup()
    : super(
        identifications: MediaIdentificationRepository(),
        embeddings: IdentificationEmbeddingRepository(),
        crops: IdentificationCropStore(supportPath: () async => '/none'),
      );

  var sweeps = 0;

  @override
  Future<int> sweepOrphans() async {
    sweeps++;
    return 0;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(
          MediaIdentificationRepository(database: db),
        ),
      ],
    );
  });
  tearDown(() async {
    resetMarineLifeIdEnabled();
    container.dispose();
    await db.close();
  });

  Future<void> seedSuggestion() => container
      .read(mediaIdentificationRepositoryProvider)
      .storeRun(run(), insert: [identification('a')], deleteIds: const []);

  test('no suggestions while the feature is switched off', () async {
    marineLifeIdEnabled = false;
    await seedSuggestion();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );
  });

  test('stored suggestions show with no pack installed', () async {
    marineLifeIdEnabled = true;
    await seedSuggestion();
    final suggestions = await container.read(
      mediaSuggestionsProvider('m1').future,
    );
    expect(suggestions.single.top.candidate.commonName, 'Queen Parrotfish');
  });

  test('suggestions follow new identifications and new tags', () async {
    marineLifeIdEnabled = true;
    final sub = container.listen(mediaSuggestionsProvider('m1'), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );

    await seedSuggestion();
    await pumpEventQueue();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      hasLength(1),
    );

    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'm1',
            filePath: '',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'sp_queen_parrotfish',
            commonName: 'Queen Parrotfish',
            scientificName: const Value('Scarus vetula'),
            category: 'fish',
          ),
        );
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 't1',
            mediaId: 'm1',
            speciesId: 'sp_queen_parrotfish',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );
  });

  group('crops', () {
    late Directory support;
    late IdentificationCropStore crops;
    late ProviderContainer withCrops;

    setUp(() async {
      support = await Directory.systemTemp.createTemp('crop_providers');
      crops = IdentificationCropStore(
        supportPath: () async => support.path,
        table: IdentificationCropRepository(database: db),
      );
      withCrops = ProviderContainer(
        overrides: [
          mediaIdentificationRepositoryProvider.overrideWithValue(
            MediaIdentificationRepository(database: db),
          ),
          identificationCropStoreProvider.overrideWithValue(crops),
          identificationCropRepositoryProvider.overrideWithValue(
            IdentificationCropRepository(database: db),
          ),
        ],
      );
    });
    tearDown(() async {
      withCrops.dispose();
      await deleteTempDir(support);
    });

    test('a crop written after it was looked for shows', () async {
      const key = ('m1', 'i1');
      final sub = withCrops.listen(identificationCropProvider(key), (_, _) {});
      addTearDown(sub.close);
      expect(
        await withCrops.read(identificationCropProvider(key).future),
        isNull,
      );
      await crops.write('m1', 'i1', Uint8List.fromList([0xFF, 0xD8]));
      await pumpEventQueue();
      expect(
        await withCrops.read(identificationCropProvider(key).future),
        isNotNull,
      );
    });

    test('a named crop synced from another device shows, and follows the '
        'logbook (issue #4876)', () async {
      const key = ('m1', 'i2');
      final sub = withCrops.listen(identificationCropProvider(key), (_, _) {});
      addTearDown(sub.close);
      expect(
        await withCrops.read(identificationCropProvider(key).future),
        isNull,
      );
      // As a sync writes it: straight into the table.
      await IdentificationCropRepository(
        database: db,
      ).put('i2', 'm1', Uint8List.fromList([0xFF, 0xD8, 9]));
      await pumpEventQueue();
      final crop = await withCrops.read(identificationCropProvider(key).future);
      expect(crop, isA<CropBytes>());
      expect((crop! as CropBytes).bytes, [0xFF, 0xD8, 9]);
    });

    test('a crop already shown is not read again when other crops sync in, '
        'so its picture is not drawn again (issue #4876)', () async {
      const key = ('m1', 'i3');
      final table = IdentificationCropRepository(database: db);
      await table.put('i3', 'm1', Uint8List.fromList([0xFF, 0xD8, 3]));
      var builds = 0;
      final sub = withCrops.listen(identificationCropProvider(key), (_, next) {
        if (next.hasValue) builds++;
      }, fireImmediately: true);
      addTearDown(sub.close);
      final shown = await withCrops.read(
        identificationCropProvider(key).future,
      );
      await pumpEventQueue();
      final before = builds;

      await table.put('other', 'm2', Uint8List.fromList([0xFF, 0xD8, 4]));
      await pumpEventQueue();

      expect(builds, before);
      expect(
        identical(
          await withCrops.read(identificationCropProvider(key).future),
          shown,
        ),
        isTrue,
      );
    });

    test('the crops size follows the files, not only the rows', () async {
      await crops.write('m1', 'i1', Uint8List.fromList([1, 2, 3, 4]));
      final sub = withCrops.listen(identificationCropBytesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await withCrops.read(identificationCropBytesProvider.future), 4);
      await crops.deleteMedia(['m1']);
      await pumpEventQueue();
      expect(await withCrops.read(identificationCropBytesProvider.future), 0);
    });
  });

  test('at launch, orphaned identifications are swept only while the '
      'feature is on', () async {
    final cleanup = _CountingCleanup();
    marineLifeIdEnabled = false;
    await sweepIdentificationOrphansAtLaunch(cleanup);
    expect(cleanup.sweeps, 0);
    marineLifeIdEnabled = true;
    await sweepIdentificationOrphansAtLaunch(cleanup);
    expect(cleanup.sweeps, 1);
  });

  test('progress follows the service (issue #4675)', () async {
    marineLifeIdEnabled = true;
    final service = RecordingIdentificationService();
    final c = ProviderContainer(
      overrides: [
        mediaIdentificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(c.dispose);
    final seen = <double?>[];
    final sub = c.listen(
      mediaIdentificationProgressProvider('v1'),
      (_, next) => seen.add(next.value),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pumpEventQueue();
    service.progress = 0.4;
    service.activity.add(null);
    await pumpEventQueue();
    service.progress = null;
    service.activity.add(null);
    await pumpEventQueue();
    expect(seen.whereType<double>(), [0.4]);
    expect(seen.last, isNull);
  });

  test('a video\'s tracks are its stored tracks only (issue #4675)', () async {
    marineLifeIdEnabled = true;
    final repository = container.read(mediaIdentificationRepositoryProvider);
    await repository.storeRun(
      videoRun(),
      insert: [
        track('t1'),
        identification('p', mediaId: 'v1'),
      ],
      deleteIds: const [],
    );
    final tracks = await container.read(videoTracksProvider('v1').future);
    expect(tracks.map((t) => t.id), ['t1']);
  });

  test('a video\'s tracks are none while switched off', () async {
    marineLifeIdEnabled = false;
    final repository = container.read(mediaIdentificationRepositoryProvider);
    await repository.storeRun(videoRun(), insert: [track('t1')], deleteIds: []);
    expect(await container.read(videoTracksProvider('v1').future), isEmpty);
  });

  group('the video file a scan reads (issue #4675)', () {
    final item = MediaItem(
      id: 'v1',
      mediaType: MediaType.video,
      takenAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      bookmarkRef: 'bm-1',
    );
    final opened = <(String?, String?)>[];
    var resolved = 0;

    /// [held]: the player on screen holds the video's playback, as the
    /// viewer does while the video is current.
    ProviderContainer withPlayback(
      VideoPlayback playback, {
      Duration takes = Duration.zero,
      bool held = true,
    }) {
      opened.clear();
      resolved = 0;
      final c = ProviderContainer(
        overrides: [
          videoPlaybackProvider(item).overrideWith((ref) async {
            resolved++;
            if (takes > Duration.zero) await Future<void>.delayed(takes);
            return playback;
          }),
          videoFileAccessProvider.overrideWithValue(<T>({
            String? path,
            String? bookmarkRef,
            required Future<T> Function(String path) read,
          }) {
            opened.add((path, bookmarkRef));
            return read('/opened$path');
          }),
        ],
      );
      addTearDown(c.dispose);
      if (held) {
        final hold = c.listen(videoPlaybackProvider(item), (_, _) {});
        addTearDown(hold.close);
      }
      return c;
    }

    test('is the file the player opened, through its bookmark', () async {
      final c = withPlayback(const FilePlayback('/videos/v1.mp4'));
      final reader = await c.read(videoFileReaderProvider(item).future);
      expect(await reader!((path) async => path), '/opened/videos/v1.mp4');
      expect(opened, [('/videos/v1.mp4', 'bm-1')]);
    });

    test('survives a one-off read while the file takes time to find', () async {
      // The service reads it once, keeping no listener, and resolving the
      // file does real IO: the provider must still be there after the wait.
      final c = withPlayback(
        const FilePlayback('/videos/v1.mp4'),
        takes: const Duration(milliseconds: 5),
      );
      final reader = await c.read(videoFileReaderProvider(item).future);
      expect(await reader!((path) async => path), '/opened/videos/v1.mp4');
    });

    test('resolves nothing of its own when no player holds the video, so a '
        'scan never fetches a file', () async {
      final c = withPlayback(const FilePlayback('/videos/v1.mp4'), held: false);
      expect(await c.read(videoFileReaderProvider(item).future), isNull);
      expect(resolved, 0);
    });

    test('reads the player\'s own resolution, not a second one', () async {
      final c = withPlayback(const FilePlayback('/videos/v1.mp4'));
      await c.read(videoPlaybackProvider(item).future);
      expect(await c.read(videoFileReaderProvider(item).future), isNotNull);
      expect(resolved, 1);
    });

    test('is none when the video does not play from a file', () async {
      final c = withPlayback(const NoPlayback(NoPlaybackReason.notFound));
      expect(await c.read(videoFileReaderProvider(item).future), isNull);
    });

    group('asked for by a later copy of the video (issue #4958)', () {
      // The Media library's items arrive without their dive enrichment,
      // which the viewer fills in while the video plays: the copy the
      // viewer asks with is then no longer the one the player resolved.
      final later = item.copyWith(updatedAt: DateTime.utc(2026, 2));

      /// The real playback body, over a file resolved by [resolvedFilePathProvider].
      ProviderContainer resolvingFiles() {
        opened.clear();
        resolved = 0;
        final c = ProviderContainer(
          overrides: [
            resolvedFilePathProvider.overrideWith((ref, _) async {
              resolved++;
              return '/videos/v1.mp4';
            }),
            videoFileAccessProvider.overrideWithValue(<T>({
              String? path,
              String? bookmarkRef,
              required Future<T> Function(String path) read,
            }) {
              opened.add((path, bookmarkRef));
              return read('/opened$path');
            }),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      test('reads the playback the player holds for the earlier copy, '
          'resolving nothing more', () async {
        final c = resolvingFiles();
        final hold = c.listen(videoPlaybackProvider(item), (_, _) {});
        addTearDown(hold.close);
        await c.read(videoPlaybackProvider(item).future);

        final reader = await c.read(videoFileReaderProvider(later).future);

        expect(await reader!((path) async => path), '/opened/videos/v1.mp4');
        expect(opened, [('/videos/v1.mp4', 'bm-1')]);
        expect(resolved, 1);
      });

      test('is none once the player lets the earlier copy go', () async {
        final c = resolvingFiles();
        final hold = c.listen(videoPlaybackProvider(item), (_, _) {});
        await c.read(videoPlaybackProvider(item).future);
        hold.close();
        // Let the playback dispose, as it does once nothing listens.
        await Future<void>.delayed(Duration.zero);

        expect(await c.read(videoFileReaderProvider(later).future), isNull);
        expect(resolved, 1);
      });

      test('never reads another video\'s playback', () async {
        final c = resolvingFiles();
        final hold = c.listen(videoPlaybackProvider(item), (_, _) {});
        addTearDown(hold.close);
        await c.read(videoPlaybackProvider(item).future);
        final other = later.copyWith(id: 'v2');

        expect(await c.read(videoFileReaderProvider(other).future), isNull);
      });
    });
  });

  test('Apple platforms get the Core ML engine', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visionEngineProvider), isA<ChannelVisionEngine>());
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android, Windows and Linux get the ONNX engine', () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final c = ProviderContainer();
      final engine = c.read(visionEngineProvider);
      c.dispose();
      expect(engine, isA<OnnxVisionEngine>(), reason: '$platform');
      expect(engine.engineName, VisionEngine.onnxEngine);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  group('the naming level (issue #4721)', () {
    // A pack is read only where the models run; the file's tearDown puts
    // the flag back.
    setUp(() => marineLifeIdEnabled = true);

    // The fixture pack names at 0.50 with a location; Eager at 0.3.
    InstalledPack levelledPack() => InstalledPack(
      manifest: SpeciesPackManifest.parse(
        manifestJson((m) {
          (m['naming']! as Map<String, Object?>)['provisional'] = false;
          (m['naming']! as Map<String, Object?>)['levels'] = [
            {
              'id': 'balanced',
              'target': 0.75,
              'suggestScore': 0.4,
              'suggestScoreNoLocation': 0.6,
              'precision': 0.8,
            },
            {
              'id': 'eager',
              'target': 0.65,
              'suggestScore': 0.3,
              'suggestScoreNoLocation': 0.5,
              'precision': 0.7,
            },
          ];
        }),
      ),
      directory: '/pack',
      detectorPaths: const ['/pack/detector'],
      classifierPath: '/pack/classifier',
    );

    group('awaitLevelInForce, the level the service reconciles at', () {
      ProviderContainer withPack(Future<InstalledPack?> Function() pack) {
        final c = ProviderContainer(
          overrides: [
            installedSpeciesPackProvider.overrideWith((ref) => pack()),
            namingLevelNotifierProvider.overrideWith(
              (ref) =>
                  NamingLevelNotifier.unstored(NamingLevel.eager, picked: true),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      test('waits for a pack still being read', () async {
        final reading = Completer<InstalledPack?>();
        final level = awaitLevelInForce(withPack(() => reading.future));
        reading.complete(levelledPack());
        expect((await level)?.level, NamingLevel.eager);
      });

      test('waits for a pack being read again, not the one before', () async {
        var reads = 0;
        final reread = Completer<InstalledPack?>();
        // The first read finds no pack; the read after an install finds
        // the levelled one.
        final c = withPack(() => ++reads == 1 ? Future.value() : reread.future);
        await c.read(installedSpeciesPackProvider.future);
        c.invalidate(installedSpeciesPackProvider);
        final level = awaitLevelInForce(c);
        reread.complete(levelledPack());
        expect((await level)?.level, NamingLevel.eager);
      });

      test('is none at once when a pack read again cannot be read, not the '
          'one before', () async {
        var reads = 0;
        // The first read finds the levelled pack; the read after an install
        // fails, and Riverpod keeps the pack before beside the error.
        final c = withPack(() async {
          if (++reads == 1) return levelledPack();
          throw StateError('no pack');
        });
        final held = c.listen(installedSpeciesPackProvider, (_, _) {});
        addTearDown(held.close);
        await c.read(installedSpeciesPackProvider.future);
        c.invalidate(installedSpeciesPackProvider);
        await pumpEventQueue();
        expect(c.read(installedSpeciesPackProvider).hasError, isTrue);
        expect(await awaitLevelInForce(c), isNull);
      });

      test('is none at once when the pack cannot be read', () async {
        final c = withPack(() async => throw StateError('no pack'));
        // Read it and let the read fail; Riverpod then retries in the
        // background.
        final held = c.listen(installedSpeciesPackProvider, (_, _) {});
        addTearDown(held.close);
        await pumpEventQueue();
        expect(c.read(installedSpeciesPackProvider).hasError, isTrue);
        expect(
          await awaitLevelInForce(c).timeout(const Duration(seconds: 2)),
          isNull,
        );
      });

      test('gives up on a read that never ends', () async {
        final c = withPack(() => Completer<InstalledPack?>().future);
        expect(
          await awaitLevelInForce(c, wait: const Duration(milliseconds: 50)),
          isNull,
        );
      });
    });

    /// A container whose pack has been read: the level never waits for it.
    Future<ProviderContainer> levelled(NamingLevel level) async {
      final c = ProviderContainer(
        overrides: [
          mediaIdentificationRepositoryProvider.overrideWithValue(
            MediaIdentificationRepository(database: db),
          ),
          installedSpeciesPackProvider.overrideWith(
            (ref) async => levelledPack(),
          ),
          namingLevelNotifierProvider.overrideWith(
            (ref) => NamingLevelNotifier.unstored(level, picked: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.awaitFuture(installedSpeciesPackProvider.future);
      final held = c.listen(installedSpeciesPackProvider, (_, _) {});
      addTearDown(held.close);
      return c;
    }

    // Its best name, the parrotfish, scored under the pack's bar but over
    // Eager's.
    MediaIdentification weak(MediaIdentification i) => i.copyWith(
      candidates: [NamedCandidate(candidate: i.top!.candidate, score: 0.35)],
      suggestable: false,
    );

    Future<void> store(MediaIdentificationRun run, MediaIdentification i) =>
        container
            .read(mediaIdentificationRepositoryProvider)
            .storeRun(run, insert: [i], deleteIds: const []);

    test('Eager offers a name the pack bars do not', () async {
      marineLifeIdEnabled = true;
      await store(run(), weak(identification('a')));
      final eager = await levelled(NamingLevel.eager);
      expect(
        await eager.read(mediaSuggestionsProvider('m1').future),
        hasLength(1),
      );
      final surer = await levelled(NamingLevel.surer);
      expect(await surer.read(mediaSuggestionsProvider('m1').future), isEmpty);
    });

    test('not on media another pack named', () async {
      marineLifeIdEnabled = true;
      await store(
        run().copyWith(packVersion: '2026.10.1'),
        weak(identification('a')),
      );
      final eager = await levelled(NamingLevel.eager);
      expect(await eager.read(mediaSuggestionsProvider('m1').future), isEmpty);
    });

    test('a video track at Eager is one the app could suggest', () async {
      marineLifeIdEnabled = true;
      await store(videoRun(), weak(track('t1', confident: false)));
      final eager = await levelled(NamingLevel.eager);
      final tracks = await eager.read(videoTracksProvider('v1').future);
      expect(tracks.single.suggestable, isTrue);
    });

    test('is Eager by default, unpicked until one is chosen, and '
        'remembered (issue #4789)', () async {
      expect(container.read(namingLevelNotifierProvider), NamingLevel.eager);
      expect(
        container.read(namingLevelNotifierProvider.notifier).picked,
        isFalse,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = NamingLevelNotifier(prefs);
      expect(notifier.state, NamingLevel.eager);
      expect(notifier.picked, isFalse);

      await notifier.setLevel(NamingLevel.balanced);
      expect(notifier.picked, isTrue);
      expect(prefs.getString(SettingsKeys.marineLifeNamingLevel), 'balanced');
      final reread = NamingLevelNotifier(prefs);
      expect(reread.state, NamingLevel.balanced);
      expect(reread.picked, isTrue);
    });

    test('an unknown stored id reads as Surer, as picked', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.marineLifeNamingLevel: 'reckless',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = NamingLevelNotifier(prefs);
      expect(notifier.state, NamingLevel.surer);
      expect(notifier.picked, isTrue);
    });

    test('where no model can run, no pack is ever read: a run\'s own bars '
        'name its rows (issue #4876)', () async {
      marineLifeIdEnabled = false;
      var reads = 0;
      final c = ProviderContainer(
        overrides: [
          installedSpeciesPackProvider.overrideWith((ref) async {
            reads++;
            return levelledPack();
          }),
          namingLevelNotifierProvider.overrideWith(
            (ref) =>
                NamingLevelNotifier.unstored(NamingLevel.eager, picked: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(levelInForceProvider), isNull);
      expect(await awaitLevelInForce(c), isNull);
      await pumpEventQueue();
      expect(reads, 0);
    });

    test('Surer is no level and never reads the pack', () async {
      var reads = 0;
      final c = ProviderContainer(
        overrides: [
          installedSpeciesPackProvider.overrideWith((ref) async {
            reads++;
            return levelledPack();
          }),
          namingLevelNotifierProvider.overrideWith(
            (ref) =>
                NamingLevelNotifier.unstored(NamingLevel.surer, picked: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(levelInForceProvider), isNull);
      await pumpEventQueue();
      expect(reads, 0);

      c.read(namingLevelNotifierProvider.notifier).setLevel(NamingLevel.eager);
      c.listen(levelInForceProvider, (_, _) {});
      await c.read(installedSpeciesPackProvider.future);
      expect(c.read(levelInForceProvider)?.level, NamingLevel.eager);
    });
  });

  test('identifying on open is on by default and remembered', () async {
    expect(container.read(identifyFishOnOpenProvider), isTrue);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stored = ProviderContainer(
      overrides: [
        identifyFishOnOpenProvider.overrideWith(
          (ref) => IdentifyFishOnOpenNotifier(prefs),
        ),
      ],
    );
    addTearDown(stored.dispose);
    await stored.read(identifyFishOnOpenProvider.notifier).setEnabled(false);
    expect(prefs.getBool(SettingsKeys.identifyFishOnOpen), isFalse);
    expect(jsonEncode(stored.read(identifyFishOnOpenProvider)), 'false');
  });
}
