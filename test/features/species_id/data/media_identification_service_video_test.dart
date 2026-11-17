import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// Counts the embeddings it is asked for.
class _CountingEmbeddings extends IdentificationEmbeddingRepository {
  _CountingEmbeddings(LocalCacheDatabase database) : super(database: database);

  var asked = 0;

  @override
  Future<Map<String, Float32List>> get(
    List<String> identificationIds, {
    required String classifierId,
  }) {
    asked += identificationIds.length;
    return super.get(identificationIds, classifierId: classifierId);
  }
}

/// Calls [onStore] after the first run it stores: where a logbook switch
/// would land between a rescan's first write and its scan.
class _StoreHookRepository extends MediaIdentificationRepository {
  _StoreHookRepository(AppDatabase database, this.onStore)
    : super(database: database);

  final void Function() onStore;
  var _stored = false;

  @override
  Future<void> storeRun(
    MediaIdentificationRun run, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
  }) async {
    await super.storeRun(run, insert: insert, deleteIds: deleteIds);
    if (!_stored) {
      _stored = true;
      onStore();
    }
  }
}

void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late MediaIdentificationRepository identifications;
  late IdentificationEmbeddingRepository embeddings;
  late IdentificationCropStore crops;
  late FakeEngine engine;
  late LoadedPack? installed;
  late bool enabled;
  late List<TaggedSpecies> tagged;
  late IdentificationImage? Function(MediaItem item) imageFor;
  late MediaIdentificationService service;
  var ids = 0;
  var generation = 0;

  /// How many file reads succeed before the file cannot be opened; null
  /// for every one.
  int? readsAllowed;

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_video');
    identifications = MediaIdentificationRepository(database: library);
    embeddings = IdentificationEmbeddingRepository(database: local);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    engine = FakeEngine();
    installed = pack();
    enabled = true;
    tagged = [];
    imageFor = (item) => IdentificationImage.path('/photos/${item.id}.jpeg');
    ids = 0;
    generation = 0;
    readsAllowed = null;
    service = MediaIdentificationService(
      engine: engine,
      loadPack: () async => installed,
      identifications: identifications,
      embeddings: embeddings,
      crops: crops,
      resolveImage: (item) async => imageFor(item),
      resolveVideo: (item) async =>
          <T>(Future<T> Function(String path) read) async {
            final allowed = readsAllowed;
            if (allowed != null) {
              if (allowed <= 0) return null;
              readsAllowed = allowed - 1;
            }
            return read('/videos/${item.id}.mp4');
          },
      taggedSpecies: (_) async => tagged,
      enabled: () => enabled,
      databaseGeneration: () => generation,
      now: () => DateTime.utc(2026, 11, 17),
      newId: () => 'id-${ids++}',
      idleUnload: const Duration(milliseconds: 50),
    );
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  group('videos (issue #4675)', () {
    MediaItem video([String id = 'v1']) => photo(id, type: MediaType.video);

    /// A fish in view from 1 s to 4 s.
    void oneFish() {
      engine.videoFrames = {
        for (var ms = 1000; ms < 4000; ms += 250)
          ms: [
            const DetectedBox(
              box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
              score: 0.9,
            ),
          ],
      };
    }

    Future<void> until(bool Function() done) async {
      for (var k = 0; k < 200 && !done(); k++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(done(), isTrue);
    }

    test('a video is scanned to the end and its fish stored', () async {
      oneFish();
      await service.request(video());
      expect(engine.detectCalls, [(0, 10000), (10000, 20000), (20000, 30000)]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.isTrack, isTrue);
      expect(fish.top!.candidate, parrotfish);
    });

    test('leaving the video stops after the chunk in progress and resumes '
        'next time', () async {
      engine.videoGate = Completer<void>();
      final done = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      expect(service.cancelPending('v1'), isTrue);
      engine.videoGate!.complete();
      await done;
      expect(engine.detectCalls, hasLength(1));
      expect((await identifications.runFor('v1'))!.scannedMs, 10000);

      engine.videoGate = null;
      await service.request(video());
      expect(engine.detectCalls[1], (10000, 20000));
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test(
      'coming back before the stopped chunk ends keeps the scan going',
      () async {
        engine.videoGate = Completer<void>();
        final first = service.request(video());
        await until(() => engine.detectCalls.length == 1);
        expect(service.cancelPending('v1'), isTrue);
        final again = service.request(video());
        engine.videoGate!.complete();
        engine.videoGate = null;
        await first;
        await again;
        expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      },
    );

    test('a location arriving for the running video does not throw its '
        'chunk away', () async {
      oneFish();
      engine.videoGate = Completer<void>();
      final first = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      final located = service.request(
        video(),
        location: const GeoPoint(20.5, -87.0),
      );
      engine.videoGate!.complete();
      engine.videoGate = null;
      await first;
      await located;
      expect(engine.detectCalls.where((c) => c.$1 == 0), hasLength(1));
      final run = (await identifications.runFor('v1'))!;
      expect(run.scanComplete, isTrue);
      expect(run.locationCell, isNotNull);
    });

    test('settleAll stops a running scan and drops queued requests before '
        'it returns', () async {
      engine.videoGate = Completer<void>();
      final scanning = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      final queued = service.request(photo('m1'));
      final settling = service.settleAll();
      engine.videoGate!.complete();
      engine.videoGate = null;
      await settling;
      expect(engine.detectCalls, hasLength(1));
      expect(engine.analysed, isEmpty);
      await scanning;
      await queued;
    });

    test('a pack change waits for one chunk, not the whole video', () async {
      engine.videoGate = Completer<void>();
      final done = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      final change = service.packChanged();
      engine.videoGate!.complete();
      await change;
      expect(engine.detectCalls, hasLength(1));
      engine.videoGate = null;
      await done;
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test(
      'a newer photo runs between chunks and the video carries on after',
      () async {
        engine.videoGate = Completer<void>();
        final scanning = service.request(video());
        await until(() => engine.detectCalls.length == 1);
        final opened = service.request(photo('m1'));
        engine.videoGate!.complete();
        engine.videoGate = null;
        await opened;
        await scanning;
        final order = engine.events
            .where(
              (e) => e.startsWith('detectVideo') || e.startsWith('analyze'),
            )
            .toList();
        expect(order.take(3), [
          'detectVideo:0',
          'analyze:/photos/m1.jpeg',
          'detectVideo:10000',
        ]);
        expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      },
    );

    test(
      'an app in the background ends the scan and keeps what was stored',
      () async {
        engine.videoFailureAt = (start) => start == 10000
            ? const VisionEngineException(VisionEngineException.notForeground)
            : null;
        await service.request(video());
        expect((await identifications.runFor('v1'))!.scannedMs, 10000);

        engine.videoFailureAt = null;
        await service.request(video());
        expect(engine.detectCalls.last, (20000, 30000));
        expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      },
    );

    test(
      'a device too hot ends the scan and the next opening resumes',
      () async {
        engine.videoFailureAt = (start) => start == 10000
            ? const VisionEngineException(VisionEngineException.tooHot)
            : null;
        await service.request(video());
        expect((await identifications.runFor('v1'))!.scannedMs, 10000);
        engine.videoFailureAt = null;
        await service.request(video());
        expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      },
    );

    test('models freed before pass 2 leave one track per fish', () async {
      oneFish();
      engine.embedFailure = const VisionEngineException(
        VisionEngineException.notLoaded,
      );
      await service.request(video());
      expect(await identifications.forMedia('v1'), hasLength(1));
      expect(engine.events.where((e) => e == 'load'), hasLength(2));
    });

    test('another logbook opening before the scan starts stores nothing in '
        'it', () async {
      oneFish();
      final switching = MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: _StoreHookRepository(library, () => generation++),
        embeddings: embeddings,
        crops: crops,
        resolveImage: (item) async => imageFor(item),
        resolveVideo: (item) async =>
            <T>(Future<T> Function(String path) read) => read('/v.mp4'),
        taggedSpecies: (_) async => tagged,
        enabled: () => enabled,
        databaseGeneration: () => generation,
      );
      addTearDown(switching.dispose);
      await switching.request(video());
      expect(engine.detectCalls, isEmpty);
      expect(await identifications.forMedia('v1'), isEmpty);
    });

    test('another logbook opening mid-scan drops the chunk', () async {
      engine.videoGate = Completer<void>();
      final done = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      generation++;
      engine.videoGate!.complete();
      await done;
      // The scan's starting row predates the switch; nothing after it is
      // stored.
      expect((await identifications.runFor('v1'))!.scannedMs, 0);
      expect(await identifications.forMedia('v1'), isEmpty);
    });

    test('progressOf follows the running video', () async {
      final seen = <double?>[];
      final sub = service.watchActivity().listen(
        (_) => seen.add(service.progressOf('v1')),
      );
      addTearDown(sub.cancel);
      await service.request(video());
      await pumpEventQueue();
      expect(seen, containsAll([0.4, 0.8]));
      expect(service.progressOf('v1'), isNull);
    });

    test('a rescan carries a dismissal to the same fish', () async {
      oneFish();
      await service.request(video());
      final first = (await identifications.forMedia('v1')).single;
      await service.reject('v1', [first.id]);

      installed = pack(detector: 'det-b');
      await service.packChanged();
      await service.request(video());
      final again = (await identifications.forMedia('v1')).single;
      expect(again.id, isNot(first.id));
      expect(again.decision, IdentificationDecision.rejected);
    });

    test('a rescan stopped part-way still carries a dismissal after it '
        'resumes', () async {
      engine.videoFrames = {
        for (var ms = 15000; ms < 18000; ms += 250)
          ms: [
            const DetectedBox(
              box: IdentificationBox(x: 0.5, y: 0.4, width: 0.2, height: 0.1),
              score: 0.9,
            ),
          ],
      };
      await service.request(video());
      final first = (await identifications.forMedia('v1')).single;
      await service.reject('v1', [first.id]);

      installed = pack(detector: 'det-b');
      await service.packChanged();
      engine.videoGate = Completer<void>();
      final stopped = service.request(video());
      await until(() => engine.detectCalls.length == 4);
      expect(service.cancelPending('v1'), isTrue);
      engine.videoGate!.complete();
      engine.videoGate = null;
      await stopped;
      expect((await identifications.runFor('v1'))!.scannedMs, 10000);

      await service.request(video());
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(1));
      expect(found.single.id, isNot(first.id));
      expect(found.single.decision, IdentificationDecision.rejected);
    });

    test('opening a scanned video again reads no embeddings and no rows '
        'twice', () async {
      oneFish();
      await service.request(video());
      final counting = _CountingEmbeddings(local);
      var reads = 0;
      final again = MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: ReadHookRepository(library, () => reads++),
        embeddings: counting,
        crops: crops,
        resolveImage: (item) async => imageFor(item),
        resolveVideo: (item) async =>
            <T>(Future<T> Function(String path) read) => read('/v.mp4'),
        taggedSpecies: (_) async => tagged,
        enabled: () => enabled,
        databaseGeneration: () => generation,
      );
      addTearDown(again.dispose);
      await again.request(video());
      expect(counting.asked, 0);
      // One read to decide, one to reconcile.
      expect(reads, 2);
    });

    test('a resume with nothing to rename reads the rows once', () async {
      engine.videoGate = Completer<void>();
      final stopped = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      service.cancelPending('v1');
      engine.videoGate!.complete();
      engine.videoGate = null;
      await stopped;
      var reads = 0;
      final again = MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: ReadHookRepository(library, () => reads++),
        embeddings: embeddings,
        crops: crops,
        resolveImage: (item) async => imageFor(item),
        resolveVideo: (item) async =>
            <T>(Future<T> Function(String path) read) => read('/v.mp4'),
        taggedSpecies: (_) async => tagged,
        enabled: () => enabled,
        databaseGeneration: () => generation,
      );
      addTearDown(again.dispose);
      await again.request(video());
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      expect(reads, 2);
    });

    test('fish kept to name later at a stop do not make the video scan '
        'again from the start', () async {
      engine.videoFrames = {
        for (var ms = 1000; ms < 15000; ms += 250)
          ms: [
            for (var k = 0; k < 6; k++)
              DetectedBox(
                box: IdentificationBox(
                  x: k / 6,
                  y: 0.4,
                  width: 0.5 / 6,
                  height: 0.1,
                ),
                score: 0.9,
              ),
          ],
      };
      engine.videoGate = Completer<void>();
      final stopped = service.request(video());
      await until(() => engine.detectCalls.length == 1);
      service.cancelPending('v1');
      engine.videoGate!.complete();
      engine.videoGate = null;
      await stopped;
      expect(
        (await identifications.forMedia('v1')).where((i) => i.isPending),
        isNotEmpty,
      );
      await service.request(video());
      expect(engine.detectCalls[1], (10000, 20000));
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(6));
      expect(found.where((i) => i.isPending), isEmpty);
    });

    test('leaving a video while pass 2 runs keeps the fish open since the '
        'chunk before', () async {
      engine.videoFrames = {
        for (var ms = 8000; ms < 14000; ms += 250)
          ms: [
            if (ms < 12000)
              const DetectedBox(
                box: IdentificationBox(
                  x: 0.05,
                  y: 0.8,
                  width: 0.1,
                  height: 0.1,
                ),
                score: 0.9,
              ),
            if (ms >= 10000)
              for (var k = 0; k < 5; k++)
                DetectedBox(
                  box: IdentificationBox(
                    x: k / 5,
                    y: 0.4,
                    width: 0.1,
                    height: 0.1,
                  ),
                  score: 0.9,
                ),
          ],
      };
      engine.onEmbedMoments = () => service.cancelPending('v1');
      await service.request(video());
      expect(engine.embedCalls, hasLength(1));
      final kept = (await identifications.forMedia('v1')).single;
      expect(kept.isPending, isTrue);
      expect((kept.startMs, kept.endMs), (8000, 9750));
    });

    test('a file that cannot be opened mid-scan keeps the fish open where '
        'the scan stopped', () async {
      engine.videoFrames = {
        for (var ms = 8000; ms < 12000; ms += 250)
          ms: [
            const DetectedBox(
              box: IdentificationBox(x: 0.05, y: 0.8, width: 0.1, height: 0.1),
              score: 0.9,
            ),
          ],
      };
      // Chunk 1 reads the file; chunk 2 finds it gone.
      readsAllowed = 1;
      await service.request(video());
      expect(engine.detectCalls, hasLength(1));
      final kept = (await identifications.forMedia('v1')).single;
      expect(kept.isPending, isTrue);
      expect((kept.startMs, kept.endMs), (8000, 9750));
    });

    test('a new pack renames a scanned video without the engine', () async {
      oneFish();
      await service.request(video());
      engine.detectCalls.clear();
      installed = pack(version: '2026.12.1');
      await service.packChanged();
      await service.request(video());
      expect(engine.detectCalls, isEmpty);
      expect((await identifications.runFor('v1'))!.packVersion, '2026.12.1');
    });
  });
}
