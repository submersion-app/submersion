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
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../data/identification_fixtures.dart';
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
      crops = IdentificationCropStore(supportPath: () async => support.path);
      withCrops = ProviderContainer(
        overrides: [
          mediaIdentificationRepositoryProvider.overrideWithValue(
            MediaIdentificationRepository(database: db),
          ),
          identificationCropStoreProvider.overrideWithValue(crops),
        ],
      );
    });
    tearDown(() async {
      withCrops.dispose();
      await deleteTempDir(support);
    });

    test('a crop written after it was looked for shows', () async {
      const key = ('m1', 'i1');
      final sub = withCrops.listen(
        identificationCropFileProvider(key),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await withCrops.read(identificationCropFileProvider(key).future),
        isNull,
      );
      await crops.write('m1', 'i1', Uint8List.fromList([0xFF, 0xD8]));
      await pumpEventQueue();
      expect(
        await withCrops.read(identificationCropFileProvider(key).future),
        isNotNull,
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
  });

  test('the engine is the channel engine, unsupported off Apple', () async {
    final engine = container.read(visionEngineProvider);
    expect(engine, isA<ChannelVisionEngine>());
    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(engine.engineName, isNull);
    }
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
