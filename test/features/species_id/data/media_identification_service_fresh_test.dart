import 'dart:async';
import 'dart:io';

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

/// Waits for [done], turning the event loop, for up to five seconds.
Future<void> _until(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done() && clock.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue);
}

/// Analysing by hand, and again from the start (issue #4825).
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
  late MediaIdentificationService service;
  var ids = 0;
  var generation = 0;
  var settled = 0;

  MediaIdentificationService build(MediaIdentificationRepository rows) =>
      MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: rows,
        embeddings: embeddings,
        crops: crops,
        resolveImage: (item) async =>
            IdentificationImage.path('/photos/${item.id}.jpeg'),
        resolveVideo: (item) async =>
            <T>(Future<T> Function(String path) read) =>
                read('/videos/${item.id}.mp4'),
        taggedSpecies: (_) async => tagged,
        // Identify on open, which a request by hand does not need.
        enabled: () => enabled,
        runEnabled: () => true,
        databaseGeneration: () => generation,
        now: () => DateTime.utc(2026, 11, 21),
        newId: () => 'id-${ids++}',
        idleUnload: const Duration(milliseconds: 50),
        firstVideoChunkMs: 10000,
        onItemSettled: (_, _) async => settled++,
      );

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_fresh');
    identifications = MediaIdentificationRepository(database: library);
    embeddings = IdentificationEmbeddingRepository(database: local);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    engine = FakeEngine();
    installed = pack();
    enabled = true;
    tagged = [];
    ids = 0;
    generation = 0;
    settled = 0;
    service = build(identifications);
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  MediaItem video([String id = 'v1']) => photo(id, type: MediaType.video);

  /// A fish in view for three seconds from [fromMs].
  void oneFish({int fromMs = 1000}) {
    engine.videoFrames = {
      for (var ms = fromMs; ms < fromMs + 3000; ms += 250)
        ms: [
          const DetectedBox(
            box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
            score: 0.9,
          ),
        ],
    };
  }

  group('a request by hand', () {
    test('runs with identify on open switched off', () async {
      enabled = false;
      await service.request(photo('m1'), byHand: true);
      expect(engine.analysed, hasLength(1));
      expect(await identifications.runFor('m1'), isNotNull);
    });

    test('is what makes the difference: an ordinary request is skipped '
        'then', () async {
      enabled = false;
      await service.request(photo('m1'));
      expect(engine.analysed, isEmpty);
    });

    test('does nothing more than an ordinary one on a photo that needs '
        'nothing', () async {
      await service.request(photo('m1'));
      await service.request(photo('m1'), byHand: true);
      expect(engine.analysed, hasLength(1));
    });
  });

  group('a fresh request for a photo', () {
    test('analyses a photo that needs nothing', () async {
      await service.request(photo('m1'));
      await service.request(photo('m1'));
      expect(engine.analysed, hasLength(1));
      await service.request(photo('m1'), fresh: true);
      expect(engine.analysed, hasLength(2));
    });

    test('runs with identify on open switched off', () async {
      enabled = false;
      await service.request(photo('m1'), fresh: true);
      expect(engine.analysed, hasLength(1));
    });

    test('brings a dismissed suggestion back, reopened', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.reject('m1', [first.id]);

      await service.request(photo('m1'), fresh: true);
      final again = (await identifications.forMedia('m1')).single;
      expect(again.id, isNot(first.id));
      expect(again.decision, IdentificationDecision.undecided);
      expect(again.reopened, isTrue);
    });

    test(
      'an ordinary analysis after it keeps the detection reopened',
      () async {
        await service.request(photo('m1'));
        final first = (await identifications.forMedia('m1')).single;
        await service.reject('m1', [first.id]);
        await service.request(photo('m1'), fresh: true);

        installed = pack(detector: 'det-b');
        await service.packChanged();
        await service.request(photo('m1'));
        expect(engine.analysed, hasLength(3));
        expect((await identifications.forMedia('m1')).single.reopened, isTrue);
      },
    );

    test('keeps an accepted detection and the name the diver gave', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.claim('m1', first.id, 'sp_x');
      tagged = [const TaggedSpecies(speciesId: 'sp_x')];
      await service.reconcile('m1');
      expect(
        (await identifications.forMedia('m1')).single.decision,
        IdentificationDecision.accepted,
      );

      await service.request(photo('m1'), fresh: true);
      final again = (await identifications.forMedia('m1')).single;
      expect(again.id, isNot(first.id));
      expect(again.decision, IdentificationDecision.accepted);
      expect(again.decidedSpeciesId, 'sp_x');
      expect(again.claimedSpeciesId, 'sp_x');
    });

    test('is followed by no auto-apply, and an ordinary one by it', () async {
      await service.request(photo('m1'));
      expect(settled, 1);
      await service.request(photo('m1'), fresh: true);
      expect(settled, 1);
      await service.request(photo('m1'));
      expect(settled, 2);
    });

    test('a photo that cannot be read keeps its dismissals', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.reject('m1', [first.id]);
      await service.dispose();
      service = MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: identifications,
        embeddings: embeddings,
        crops: crops,
        resolveImage: (_) async => null,
        taggedSpecies: (_) async => tagged,
        enabled: () => enabled,
        databaseGeneration: () => generation,
        now: () => DateTime.utc(2026, 11, 21),
        newId: () => 'id-${ids++}',
        idleUnload: const Duration(milliseconds: 50),
      );
      await service.request(photo('m1'), fresh: true);
      final still = (await identifications.forMedia('m1')).single;
      expect(still.decision, IdentificationDecision.rejected);
    });

    test('a photo whose analysis fails keeps its dismissals', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.reject('m1', [first.id]);
      engine.failure = const VisionEngineException('analysis_failed');
      await service.request(photo('m1'), fresh: true);
      final still = (await identifications.forMedia('m1')).single;
      expect(still.decision, IdentificationDecision.rejected);
      expect(still.reopened, isFalse);
    });

    test('asked for in a logbook since closed writes nothing', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.reject('m1', [first.id]);
      await service.dispose();

      // Another logbook opens as the fresh job reads the photo's rows.
      var reads = 0;
      service = build(
        ReadHookRepository(library, () {
          if (reads++ == 0) generation++;
        }),
      );
      await service.request(photo('m1'), fresh: true);
      final still = (await identifications.forMedia('m1')).single;
      expect(still.id, first.id);
      expect(still.decision, IdentificationDecision.rejected);
      expect(engine.analysed, hasLength(1));
    });

    test('from a dive run reopens too and reports done', () async {
      await service.request(photo('m1'));
      final first = (await identifications.forMedia('m1')).single;
      await service.reject('m1', [first.id]);

      final outcome = await service.requestFromRun(
        photo('m1'),
        resolveImage: (item) async =>
            IdentificationImage.path('/photos/${item.id}.jpeg'),
        resolveVideo: (_) async => null,
        fresh: true,
      );
      expect(outcome, RunItemOutcome.done);
      expect(engine.analysed, hasLength(2));
      expect((await identifications.forMedia('m1')).single.reopened, isTrue);
    });

    test('an ordinary request from a dive run still finds nothing to do '
        'on an analysed photo', () async {
      await service.request(photo('m1'));
      await service.requestFromRun(
        photo('m1'),
        resolveImage: (item) async =>
            IdentificationImage.path('/photos/${item.id}.jpeg'),
        resolveVideo: (_) async => null,
      );
      expect(engine.analysed, hasLength(1));
    });
  });

  group('a fresh request for a video', () {
    test('scans from the start', () async {
      oneFish();
      await service.request(video());
      expect(engine.detectCalls, hasLength(3));

      await service.request(video(), fresh: true);
      expect(engine.detectCalls.sublist(3), [
        (0, 10000),
        (10000, 20000),
        (20000, 25000),
      ]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test(
      'brings a dismissed fish back, reopened, on its fresh track',
      () async {
        oneFish();
        await service.request(video());
        final first = (await identifications.forMedia('v1')).single;
        await service.reject('v1', [first.id]);

        await service.request(video(), fresh: true);
        final again = (await identifications.forMedia('v1')).single;
        expect(again.id, isNot(first.id));
        expect(again.decision, IdentificationDecision.undecided);
        expect(again.reopened, isTrue);
      },
    );

    test('put back for other work resumes instead of restarting', () async {
      oneFish();
      await service.request(video());
      expect(engine.detectCalls, hasLength(3));

      // The fresh scan's first chunk runs through; its second waits.
      engine.onEmbedMoments = () => engine.videoGate ??= Completer<void>();
      final fresh = service.request(video(), fresh: true);
      await _until(() => engine.detectCalls.length == 5);
      engine.onEmbedMoments = null;
      // Another item is asked for while the second chunk runs.
      final other = service.request(photo('m2'));
      engine.videoGate!.complete();
      engine.videoGate = null;
      await other;
      await fresh;
      // It gave way to the photo after its second chunk, and went on from
      // there: the start is scanned once.
      expect(engine.detectCalls.sublist(3), [
        (0, 10000),
        (10000, 20000),
        (20000, 25000),
      ]);
      final photoAt = engine.events.indexOf('analyze:/photos/m2.jpeg');
      expect(
        photoAt,
        greaterThan(engine.events.lastIndexOf('detectVideo:10000')),
      );
      expect(photoAt, lessThan(engine.events.lastIndexOf('detectVideo:20000')));
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      expect(await identifications.forMedia('v1'), hasLength(1));
    });

    test('while the same video is being scanned restarts it once', () async {
      oneFish();
      engine.videoGate = Completer<void>();
      final viewing = service.request(video());
      await _until(() => engine.detectCalls.length == 1);
      final fresh = service.request(video(), fresh: true);
      engine.videoGate!.complete();
      engine.videoGate = null;
      await viewing;
      await fresh;
      expect(engine.detectCalls, [
        (0, 10000),
        (0, 10000),
        (10000, 20000),
        (20000, 25000),
      ]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      expect(await identifications.forMedia('v1'), hasLength(1));
    });

    test('left part-way, an ordinary request carries on and the dismissed '
        'fish ahead still comes back reopened', () async {
      // In the second chunk, which the fresh scan is left before reaching.
      oneFish(fromMs: 12000);
      await service.request(video());
      final first = (await identifications.forMedia('v1')).single;
      await service.reject('v1', [first.id]);

      engine.videoGate = Completer<void>();
      final fresh = service.request(video(), fresh: true);
      await _until(() => engine.detectCalls.length == 4);
      expect(service.cancelPending('v1'), isTrue);
      engine.videoGate!.complete();
      engine.videoGate = null;
      await fresh;
      expect((await identifications.runFor('v1'))!.scannedMs, 10000);

      await service.request(video());
      expect(engine.detectCalls.sublist(4), [(10000, 20000), (20000, 25000)]);
      final again = (await identifications.forMedia('v1')).single;
      expect(again.id, isNot(first.id));
      expect(again.reopened, isTrue);
    });

    test('a video that cannot be read is followed by no auto-apply', () async {
      oneFish();
      await service.request(video());
      expect(settled, 1);
      await service.dispose();
      service = MediaIdentificationService(
        engine: engine,
        loadPack: () async => installed,
        identifications: identifications,
        embeddings: embeddings,
        crops: crops,
        resolveImage: (_) async => null,
        resolveVideo: (_) async => null,
        taggedSpecies: (_) async => tagged,
        enabled: () => enabled,
        databaseGeneration: () => generation,
        now: () => DateTime.utc(2026, 11, 21),
        newId: () => 'id-${ids++}',
        idleUnload: const Duration(milliseconds: 50),
        onItemSettled: (_, _) async => settled++,
      );
      await service.request(video(), fresh: true);
      expect(settled, 1);
    });

    test('is followed by no auto-apply', () async {
      oneFish();
      await service.request(video());
      expect(settled, 1);
      await service.request(video(), fresh: true);
      expect(settled, 1);
    });

    test('a dismissed fish the whole fresh scan does not find again is '
        'dropped', () async {
      oneFish();
      await service.request(video());
      final first = (await identifications.forMedia('v1')).single;
      await service.reject('v1', [first.id]);

      engine.videoFrames = {};
      await service.request(video(), fresh: true);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      expect(await identifications.forMedia('v1'), isEmpty);
    });

    test('keeps the video\'s length from the start, so the analysed '
        'stretches show at once', () async {
      oneFish();
      await service.request(video());
      engine.videoGate = Completer<void>();
      final fresh = service.request(video(), fresh: true);
      await _until(() => engine.detectCalls.length == 4);
      final started = (await identifications.runFor('v1'))!;
      engine.videoGate!.complete();
      engine.videoGate = null;
      await fresh;
      expect(started.scannedMs, 0);
      expect(started.videoDurationMs, 25000);
    });

    test('put back, then asked again with a place, is still followed by '
        'no auto-apply', () async {
      oneFish();
      await service.request(video());
      expect(settled, 1);
      engine.onEmbedMoments = () => engine.videoGate ??= Completer<void>();
      final fresh = service.request(video(), fresh: true);
      await _until(() => engine.detectCalls.length == 5);
      engine.onEmbedMoments = null;
      // A photo is asked for, and held while it is analysed.
      engine.gate = Completer<void>();
      final other = service.request(photo('m2'));
      engine.videoGate!.complete();
      engine.videoGate = null;
      await _until(() => engine.analysed.contains('/photos/m2.jpeg'));
      // The place arrives while the fresh scan waits to carry on.
      final placed = service.request(
        video(),
        location: const GeoPoint(12.15, -68.28),
      );
      engine.gate!.complete();
      engine.gate = null;
      await other;
      await placed;
      await fresh;
      expect(settled, 2);
    });
  });
}
