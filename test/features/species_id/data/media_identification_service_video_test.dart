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
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/wait_until.dart';
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

/// Waits for [done], turning the event loop, for up to five seconds.
///
/// A wall-clock budget, not a count of turns: the scan writes crops with
/// real file I/O, and on a loaded CI runner 200 turns ran out first.
Future<void> until(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done() && clock.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue);
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
      // Whole 10 s chunks from the start, as these tests were written for;
      // the short first chunk has its own tests (issue #4709).
      firstVideoChunkMs: 10000,
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

    group('where videos are not scanned (Linux)', () {
      late MediaIdentificationService photosOnly;
      var resolved = 0;

      setUp(() {
        resolved = 0;
        photosOnly = MediaIdentificationService(
          engine: engine,
          loadPack: () async => installed,
          identifications: identifications,
          embeddings: embeddings,
          crops: crops,
          resolveImage: (item) async => imageFor(item),
          resolveVideo: (item) async {
            resolved++;
            return null;
          },
          taggedSpecies: (_) async => tagged,
          enabled: () => enabled,
          videoRuns: () => false,
          databaseGeneration: () => generation,
          now: () => DateTime.utc(2026, 11, 17),
          newId: () => 'id-${ids++}',
          idleUnload: const Duration(milliseconds: 50),
        );
      });
      tearDown(() => photosOnly.dispose());

      test('a viewer video request is skipped, its file never read', () async {
        oneFish();
        await photosOnly.request(video());
        expect(engine.detectCalls, isEmpty);
        expect(resolved, 0);
        expect(await identifications.runFor('v1'), isNull);
      });

      test('a run passes over a video without counting it as failed', () async {
        final outcome = await photosOnly.requestFromRun(
          video(),
          resolveImage: (item) async => imageFor(item),
          resolveVideo: (item) async {
            resolved++;
            return null;
          },
        );
        expect(outcome, RunItemOutcome.skipped);
        expect(resolved, 0);
      });

      test('a photo is still analysed', () async {
        await photosOnly.request(photo('p1'));
        expect(await identifications.runFor('p1'), isNotNull);
      });
    });

    test('a video is scanned to the end and its fish stored', () async {
      oneFish();
      await service.request(video());
      expect(engine.detectCalls, [(0, 10000), (10000, 20000), (20000, 25000)]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.isTrack, isTrue);
      expect(fish.top!.candidate, parrotfish);
    });

    test('leaving the video stops after the chunk in progress and resumes '
        'next time', () async {
      engine.videoGate = Completer<void>();
      final done = service.request(video());
      await _until(() => engine.detectCalls.length == 1);
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

    // A Find species run scans its videos to the end (issue #4727).
    Future<RunItemOutcome> fromRun(MediaItem item) => service.requestFromRun(
      item,
      resolveImage: (_) async => null,
      resolveVideo: (item) async =>
          <T>(Future<T> Function(String path) read) =>
              read('/videos/${item.id}.mp4'),
    );

    test(
      'the viewer leaving a video does not stop a run\'s scan of it',
      () async {
        engine.videoGate = Completer<void>();
        final run = fromRun(video());
        await _until(() => engine.detectCalls.length == 1);
        expect(service.cancelPending('v1'), isFalse);
        engine.videoGate!.complete();
        engine.videoGate = null;
        expect(await run, RunItemOutcome.done);
        expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      },
    );

    test('a run asking for a video the viewer is scanning still scans it to '
        'the end when the viewer leaves', () async {
      engine.videoGate = Completer<void>();
      final viewing = service.request(video());
      await _until(() => engine.detectCalls.length == 1);
      final run = fromRun(video());
      expect(service.cancelPending('v1'), isTrue);
      engine.videoGate!.complete();
      engine.videoGate = null;
      await viewing;
      expect(await run, RunItemOutcome.done);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test(
      'coming back before the stopped chunk ends keeps the scan going',
      () async {
        engine.videoGate = Completer<void>();
        final first = service.request(video());
        await _until(() => engine.detectCalls.length == 1);
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
      await _until(() => engine.detectCalls.length == 1);
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
      await _until(() => engine.detectCalls.length == 1);
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
      await _until(() => engine.detectCalls.length == 1);
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
        await _until(() => engine.detectCalls.length == 1);
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
        expect(engine.detectCalls.last, (20000, 25000));
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
      await _until(() => engine.detectCalls.length == 1);
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

    test('the rescan by a new tracker takes up every dismissed part of a '
        'fish it joins (issue #4729)', () async {
      // In view across the first chunk's end: its second part is reached
      // only after the track is stored with the first part's dismissal.
      engine.videoFrames = {
        for (var ms = 8000; ms < 12000; ms += 250)
          ms: [
            const DetectedBox(
              box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
              score: 0.9,
            ),
          ],
      };
      await service.request(video());
      await service.reject('v1', [
        (await identifications.forMedia('v1')).single.id,
      ]);
      final dismissed = (await identifications.forMedia('v1')).single;
      MediaIdentification part(String id, int from, int to) {
        final path = [
          for (final s in dismissed.path)
            if (s.ms >= from && s.ms <= to) s,
        ];
        return dismissed.copyWith(
          id: id,
          path: path,
          startMs: () => path.first.ms,
          endMs: () => path.last.ms,
          bestMs: () => path.first.ms,
        );
      }

      // As the earlier tracker left it: two parts, each dismissed.
      final scanned = (await identifications.runFor('v1'))!;
      await identifications.storeRun(
        MediaIdentificationRun(
          mediaId: scanned.mediaId,
          packVersion: scanned.packVersion,
          detectorId: 'det-a',
          classifierId: scanned.classifierId,
          locationCell: scanned.locationCell,
          analysedAt: scanned.analysedAt,
          imageWidth: scanned.imageWidth,
          imageHeight: scanned.imageHeight,
          detectionCount: 2,
          scannedMs: scanned.scannedMs,
          videoDurationMs: scanned.videoDurationMs,
          scannedRanges: scanned.scannedRanges,
        ),
        insert: [part('p1', 8000, 9750), part('p2', 10000, 11750)],
        deleteIds: [dismissed.id],
      );
      await service.request(video());
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(1));
      expect(found.single.decision, IdentificationDecision.rejected);
      expect(found.single.startMs, 8000);
      expect(found.single.endMs, 11750);
      expect((await identifications.runFor('v1'))!.detectionCount, 1);
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
      await _until(() => engine.detectCalls.length == 4);
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
      await _until(() => engine.detectCalls.length == 1);
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
      // One read to decide, one where the scan's run starts (issue #4709),
      // one reconcile after each of its three chunks and one at the end.
      expect(reads, 6);
    });

    test('fish kept to name later at a stop do not make the video scan '
        'again from the start', () async {
      // Arriving under a second before the first chunk's end, so none is
      // named early (issue #4709).
      engine.videoFrames = {
        for (var ms = 9250; ms < 15000; ms += 250)
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
      await _until(() => engine.detectCalls.length == 1);
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
      // The crossing fish is in view under a second at the first chunk's
      // end, so it is not named early (issue #4709).
      engine.videoFrames = {
        for (var ms = 9000; ms < 14000; ms += 250)
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
      expect((kept.startMs, kept.endMs), (9000, 9750));
    });

    test('a file that cannot be opened mid-scan keeps the fish open where '
        'the scan stopped', () async {
      engine.videoFrames = {
        for (var ms = 9000; ms < 12000; ms += 250)
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
      expect((kept.startMs, kept.endMs), (9000, 9750));
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

    test('a video tracked by the earlier tracker is scanned again', () async {
      oneFish();
      await service.request(video());
      final scanned = (await identifications.runFor('v1'))!;
      // As a scan made before the run named its tracker stored it.
      await identifications.storeRun(
        MediaIdentificationRun(
          mediaId: scanned.mediaId,
          packVersion: scanned.packVersion,
          detectorId: 'det-a',
          classifierId: scanned.classifierId,
          locationCell: scanned.locationCell,
          analysedAt: scanned.analysedAt,
          imageWidth: scanned.imageWidth,
          imageHeight: scanned.imageHeight,
          detectionCount: scanned.detectionCount,
          scannedMs: scanned.scannedMs,
          videoDurationMs: scanned.videoDurationMs,
          scannedRanges: scanned.scannedRanges,
        ),
        insert: const [],
        deleteIds: const [],
      );
      engine.detectCalls.clear();
      await service.request(video());
      expect(engine.detectCalls, isNotEmpty);
      expect(
        (await identifications.runFor('v1'))!.detectorId,
        videoRunDetectorId('det-a'),
      );
      expect(await identifications.forMedia('v1'), hasLength(1));
    });

    test('a renamed video track keeps a suggestion only under the same '
        'name', () async {
      oneFish();
      await service.request(video());
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.top!.candidate, parrotfish);
      expect(fish.suggestable, isTrue);
      // As if the pack before had named it another species.
      await identifications.updateNames([
        fish.copyWith(
          candidates: const [NamedCandidate(candidate: tang, score: 0.9)],
        ),
      ], run: (await identifications.runFor('v1'))!);

      installed = pack(version: '2026.12.1');
      await service.packChanged();
      await service.request(video());
      final renamed = (await identifications.forMedia('v1')).single;
      expect(renamed.top!.candidate, parrotfish);
      expect(renamed.suggestable, isFalse);
    });

    test('a renamed video track under the same name stays '
        'suggested', () async {
      oneFish();
      await service.request(video());
      installed = pack(version: '2026.12.1');
      await service.packChanged();
      await service.request(video());
      expect((await identifications.forMedia('v1')).single.suggestable, isTrue);
    });
  });

  group('following the playhead (issue #4709)', () {
    MediaItem video([String id = 'v1']) => photo(id, type: MediaType.video);

    setUp(() => engine.videoDurationMs = 60000);

    test('a seek reported while a video is scanned moves its next '
        'chunk', () async {
      engine.videoGate = Completer<void>();
      final done = service.request(video());
      await _until(() => engine.detectCalls.length == 1);
      service.followPlayhead('v1', 40000, seek: true);
      engine.videoGate!.complete();
      engine.videoGate = null;
      await done;
      expect(engine.detectCalls.take(3), [
        (0, 10000),
        (40000, 50000),
        (50000, 60000),
      ]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test('a report made before the scan starts is used for its first '
        'chunk', () async {
      service.followPlayhead('v1', 30000, seek: true);
      await service.request(video());
      expect(engine.detectCalls.first, (30000, 40000));
    });

    test('leaving the video forgets its report', () async {
      service.followPlayhead('v1', 30000, seek: true);
      service.forgetPlayhead('v1');
      await service.request(video());
      expect(engine.detectCalls.first, (0, 10000));
    });

    test('a page covering the video keeps its report', () async {
      service.followPlayhead('v1', 30000, seek: true);
      // The trigger stops the scan while a full page covers the viewer.
      service.cancelPending('v1');
      await service.request(video());
      expect(engine.detectCalls.first, (30000, 40000));
    });

    test('a pause does not replace a seek the scan has not followed '
        'yet', () async {
      service.followPlayhead('v1', 35000, seek: true);
      service.followPlayhead('v1', 36000, seek: false);
      expect(service.playheadOf('v1')!.seek, isTrue);
      expect(service.playheadOf('v1')!.ms, 36000);
    });

    test('a pause after a seek the scan followed stays a pause', () async {
      service.followPlayhead('v1', 30000, seek: true);
      await service.request(video());
      service.followPlayhead('v1', 31000, seek: false);
      expect(service.playheadOf('v1')!.seek, isFalse);
    });

    test('a report for another video changes nothing', () async {
      service.followPlayhead('v2', 30000, seek: true);
      await service.request(video());
      expect(engine.detectCalls.first, (0, 10000));
    });

    test('a tag accepts a fish named mid-scan before the scan ends', () async {
      engine.videoFrames = {
        for (var ms = 1000; ms < 4000; ms += 250)
          ms: [
            const DetectedBox(
              box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
              score: 0.9,
            ),
          ],
      };
      tagged = [
        TaggedSpecies(
          speciesId: 'sp_queen_parrotfish',
          scientificName: parrotfish.scientificName,
        ),
      ];
      // Hold the second chunk, so the first is stored and the scan is
      // still running.
      engine.videoFailureAt = (start) {
        if (start == 0) engine.videoGate = Completer<void>();
        return null;
      };
      final done = service.request(video());
      await _until(() => engine.detectCalls.length == 2);
      await _until(() => service.progressOf('v1') != null);
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.decision, IdentificationDecision.accepted);
      expect(fish.decidedSpeciesId, 'sp_queen_parrotfish');
      engine.videoFailureAt = null;
      engine.videoGate!.complete();
      engine.videoGate = null;
      await done;
    });
  });
}

/// Waits for [done] on the shared wall-clock budget, not a count of
/// event-loop turns: the scan's real file writes can need more turns than
/// any fixed number when CI runs many test files in one isolate (issue
/// #4796). Every wait here is behind a gate, so the state holds still.
Future<void> _until(bool Function() done) => waitUntil(() async => done());
