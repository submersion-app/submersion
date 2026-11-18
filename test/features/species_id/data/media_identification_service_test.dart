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
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

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
  late bool videoReadable;
  late MediaIdentificationService service;
  var ids = 0;
  var packLoads = 0;
  var generation = 0;
  Completer<void>? tagsGate;
  var tagsAsked = 0;

  MediaIdentificationService build({MemoryReadout? memoryReadout}) =>
      MediaIdentificationService(
        memoryReadout: memoryReadout,
        engine: engine,
        loadPack: () async {
          packLoads++;
          return installed;
        },
        identifications: identifications,
        embeddings: embeddings,
        crops: crops,
        resolveImage: (item) async => imageFor(item),
        resolveVideo: (item) async {
          if (!videoReadable) return null;
          return <T>(Future<T> Function(String path) read) =>
              read('/videos/${item.id}.mp4');
        },
        taggedSpecies: (_) async {
          tagsAsked++;
          await tagsGate?.future;
          return tagged;
        },
        enabled: () => enabled,
        databaseGeneration: () => generation,
        now: () => DateTime.utc(2026, 11, 17),
        newId: () => 'id-${ids++}',
        idleUnload: const Duration(milliseconds: 50),
      );

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_service');
    identifications = MediaIdentificationRepository(database: library);
    embeddings = IdentificationEmbeddingRepository(database: local);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    engine = FakeEngine();
    installed = pack();
    enabled = true;
    tagged = [];
    imageFor = (item) => IdentificationImage.path('/photos/${item.id}.jpeg');
    videoReadable = true;
    ids = 0;
    packLoads = 0;
    generation = 0;
    tagsGate = null;
    tagsAsked = 0;
    service = build();
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  group('does nothing', () {
    test('when switched off', () async {
      enabled = false;
      await service.request(photo('m1'));
      expect(await identifications.runFor('m1'), isNull);
      expect(engine.analysed, isEmpty);
    });

    test('for a video with no file to read', () async {
      videoReadable = false;
      await service.request(photo('v1', type: MediaType.video));
      expect(engine.analysed, isEmpty);
      expect(await identifications.runFor('v1'), isNull);
    });

    test('when the engine is not available here', () async {
      engine.available = VisionAvailability.deviceNotEligible;
      await service.request(photo('m1'));
      expect(engine.analysed, isEmpty);
    });

    test('when no pack is installed', () async {
      installed = null;
      await service.request(photo('m1'));
      expect(engine.analysed, isEmpty);
    });

    test('when no image is available, and tries again next time', () async {
      imageFor = (_) => null;
      await service.request(photo('m1'));
      expect(await identifications.runFor('m1'), isNull);
      imageFor = (item) => IdentificationImage.path('/photos/${item.id}.jpeg');
      await service.request(photo('m1'));
      expect(await identifications.runFor('m1'), isNotNull);
    });

    test('when the engine fails, and does not throw', () async {
      engine.failure = Exception('boom');
      await expectLater(service.request(photo('m1')), completes);
      expect(await identifications.runFor('m1'), isNull);
    });
  });

  test('a first analysis stores the run, identifications, embeddings and '
      'crops', () async {
    engine.embeddings = [
      Float32List.fromList([1, 0, 0]),
      Float32List.fromList([0, 1, 0]),
    ];
    await service.request(photo('m1'), location: const GeoPoint(12.1, -68.3));

    final run = (await identifications.runFor('m1'))!;
    expect(run.packVersion, '2026.11.1');
    expect(run.detectorId, 'det-a');
    expect(run.classifierId, 'clf-a');
    expect(run.locationCell, isNotNull);
    expect(run.imageWidth, 4000);
    expect(run.detectionCount, 2);
    final found = await identifications.forMedia('m1');
    expect(found.map((i) => i.top!.candidate), [parrotfish, chromis]);
    expect(found.every((i) => i.suggestable), isTrue);
    expect(found.first.locationLimited, isTrue);
    expect(found.first.boxPixelWidth, 800);
    expect(
      await embeddings.get(
        found.map((i) => i.id).toList(),
        classifierId: 'clf-a',
      ),
      hasLength(2),
    );
    expect(
      await crops.allPresent('m1', found.map((i) => i.id).toList()),
      isTrue,
    );
    expect(
      engine.loads.single.detectors.single.path,
      endsWith('detector.mlpackage'),
    );
  });

  test(
    'a photo with nothing found is recorded and not analysed again',
    () async {
      engine.embeddings = [];
      await service.request(photo('m1'));
      expect((await identifications.runFor('m1'))!.detectionCount, 0);
      await service.request(photo('m1'));
      expect(engine.analysed, hasLength(1));
    },
  );

  test('an analysis stores whether each fish is confident and specific '
      '(issue #4675)', () async {
    await service.request(photo('m1'), location: const GeoPoint(12.1, -68.3));
    final found = (await identifications.forMedia('m1')).single;
    expect(found.confident, isTrue);
    expect(found.specific, isTrue);
  });

  test('a rename keeps the flags up to date', () async {
    await service.request(photo('m1'));
    installed = pack(version: '2026.12.1');
    await service.packChanged();
    await service.request(photo('m1'));
    final found = (await identifications.forMedia('m1')).single;
    expect(found.confident, isTrue);
    expect(found.specific, isTrue);
  });

  test('nothing changed means no second analysis', () async {
    await service.request(photo('m1'));
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(1));
  });

  test('a new pack with the same models renames without the engine', () async {
    await service.request(photo('m1'));
    installed = pack(version: '2026.12.1');
    await service.packChanged();
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(1));
    expect((await identifications.runFor('m1'))!.packVersion, '2026.12.1');
  });

  test('a photo that gains a location is named again', () async {
    await service.request(photo('m1'));
    expect((await identifications.runFor('m1'))!.locationCell, isNull);
    await service.request(photo('m1'), location: const GeoPoint(12.1, -68.3));
    expect(engine.analysed, hasLength(1));
    expect((await identifications.runFor('m1'))!.locationCell, isNotNull);
    expect(
      (await identifications.forMedia('m1')).single.locationLimited,
      isTrue,
    );
  });

  test('a new classifier analyses again', () async {
    await service.request(photo('m1'));
    installed = pack(version: '2026.12.1', classifier: 'clf-b');
    await service.packChanged();
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    expect((await identifications.runFor('m1'))!.classifierId, 'clf-b');
  });

  test('a pack that adds a second detector analyses again and stores both '
      'ids', () async {
    await service.request(photo('m1'));
    expect((await identifications.runFor('m1'))!.detectorId, 'det-a');
    installed = pack(version: '2026.12.1', secondDetector: 'det-m');
    await service.packChanged();
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    expect((await identifications.runFor('m1'))!.detectorId, 'det-a+det-m');
    expect(engine.loads.last.detectors.map((d) => d.path), [
      '/pack/2026.12.1/detector/detector.mlpackage',
      '/pack/2026.12.1/detector-megalodon/detector-megalodon.mlpackage',
    ]);
  });

  test(
    'a pair pack with the same detectors renames without the engine',
    () async {
      installed = pack(secondDetector: 'det-m');
      await service.request(photo('m1'));
      installed = pack(version: '2026.12.1', secondDetector: 'det-m');
      await service.packChanged();
      await service.request(photo('m1'));
      expect(engine.analysed, hasLength(1));
      expect((await identifications.runFor('m1'))!.detectorId, 'det-a+det-m');
    },
  );

  test('a new crop fitting analyses again: old embeddings were fitted the '
      'other way', () async {
    await service.request(photo('m1'));
    installed = pack(version: '2026.12.1', cropFit: 'centreCrop');
    await service.packChanged();
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    expect(
      (await identifications.runFor('m1'))!.classifierId,
      'clf-a/centreCrop',
    );
  });

  test('a missing crop analyses again', () async {
    await service.request(photo('m1'));
    await crops.deleteMedia(['m1']);
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    final found = await identifications.forMedia('m1');
    expect(
      await crops.allPresent('m1', found.map((i) => i.id).toList()),
      isTrue,
    );
  });

  test('a dismissal survives analysing again', () async {
    await service.request(photo('m1'));
    final first = (await identifications.forMedia('m1')).single;
    await service.reject('m1', [first.id]);
    await crops.deleteMedia(['m1']);
    await service.request(photo('m1'));

    final after = await identifications.forMedia('m1');
    expect(after, hasLength(1));
    expect(after.single.decision, IdentificationDecision.rejected);
  });

  test('reconciling records what the tags say', () async {
    await service.request(photo('m1'));
    tagged = [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')];
    await service.reconcile('m1');
    final accepted = (await identifications.forMedia('m1')).single;
    expect(accepted.decision, IdentificationDecision.accepted);
    expect(accepted.decidedSpeciesId, 'sp_queen_parrotfish');
  });

  test('requests run one at a time, newest first', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    final c = service.request(photo('c'));
    expect(service.isBusy('a'), isTrue);
    expect(service.isBusy('b'), isTrue);
    engine.gate!.complete();
    await Future.wait([a, b, c]);
    // c was queued after b, so it ran first.
    expect(engine.analysed, [
      '/photos/a.jpeg',
      '/photos/c.jpeg',
      '/photos/b.jpeg',
    ]);
  });

  test('a queued request can be dropped', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    service.cancelPending('b');
    engine.gate!.complete();
    await Future.wait([a, b]);
    expect(await identifications.runFor('b'), isNull);
    expect(service.isBusy('b'), isFalse);
  });

  test('the models are unloaded after a quiet spell', () async {
    await service.request(photo('m1'));
    expect(engine.unloads, 0);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(engine.unloads, 1);
  });

  test('a quiet spell that ends while a photo is looked at again still '
      'unloads the models, and frees the pack', () async {
    await service.request(photo('m1'));
    tagsGate = Completer<void>();
    // Nothing to do for m1, but the job is still running when the idle
    // timer fires.
    final again = service.request(photo('m1'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    tagsGate!.complete();
    await again;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(engine.unloads, 1);
    await service.request(photo('m2'));
    expect(packLoads, 2);
  });

  test('models the system unloaded are loaded again', () async {
    await service.request(photo('m1'));
    // An iOS memory warning frees them behind the service's back.
    engine.loaded = false;
    await service.request(photo('m2'));
    expect(await identifications.runFor('m2'), isNotNull);
    expect(engine.loads, hasLength(2));
  });

  test('a decided identification whose crop cannot come back does not '
      'analyse the photo at every opening', () async {
    await service.request(photo('m1'));
    final first = (await identifications.forMedia('m1')).single;
    await service.reject('m1', [first.id]);
    // A restore onto another device: the rows came, the crops did not, and
    // this time the detector names the fish differently.
    await crops.deleteMedia(['m1']);
    engine.embeddings = [
      Float32List.fromList([0, 1, 0]),
    ];
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    await service.request(photo('m1'));
    expect(engine.analysed, hasLength(2));
    final kept = await identifications.forMedia('m1');
    expect(
      kept.map((i) => i.decision),
      containsAll([
        IdentificationDecision.rejected,
        IdentificationDecision.undecided,
      ]),
    );
  });

  test('a queued photo uses the location given last', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    final again = service.request(
      photo('b'),
      location: const GeoPoint(12.1, -68.3),
    );
    engine.gate!.complete();
    await Future.wait([a, b, again]);
    expect((await identifications.runFor('b'))!.locationCell, isNotNull);
  });

  test('a location that arrives while the photo is analysed names it '
      'again', () async {
    engine.gate = Completer<void>();
    final first = service.request(photo('a'));
    await pumpEventQueue();
    final second = service.request(
      photo('a'),
      location: const GeoPoint(12.1, -68.3),
    );
    engine.gate!.complete();
    await Future.wait([first, second]);
    expect(engine.analysed, hasLength(1));
    expect((await identifications.runFor('a'))!.locationCell, isNotNull);
  });

  test('dropping a request says whether one was waiting', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    expect(service.cancelPending('a'), isFalse);
    expect(service.cancelPending('b'), isTrue);
    expect(service.cancelPending('b'), isFalse);
    engine.gate!.complete();
    await Future.wait([a, b]);
  });

  test('what was found is dropped when another logbook opened during the '
      'analysis', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    generation++;
    engine.gate!.complete();
    await a;
    expect(await identifications.runFor('a'), isNull);
  });

  test('a pack change waits for the analysis under way', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    var changed = false;
    final change = service.packChanged().then((_) => changed = true);
    await pumpEventQueue();
    expect(changed, isFalse);
    expect(engine.unloads, 0);
    engine.gate!.complete();
    await Future.wait([a, change]);
    expect(await identifications.runFor('a'), isNotNull);
    expect(engine.unloads, 1);
  });

  test('a pack change holds new analyses until the change is done', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    final change = service.changePack(() async => engine.events.add('change'));
    engine.gate!.complete();
    await Future.wait([a, b, change]);
    expect(engine.events, [
      'load',
      'analyze:/photos/a.jpeg',
      'unload',
      'change',
      'load',
      'analyze:/photos/b.jpeg',
    ]);
  });

  test('a logbook switch while reconciling records nothing', () async {
    tagsGate = Completer<void>();
    final a = service.request(photo('m1'));
    // Reconciling has read the rows and now waits on the tags.
    while (tagsAsked == 0) {
      await pumpEventQueue();
    }
    generation++;
    tagged = [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')];
    tagsGate!.complete();
    await a;
    expect(
      (await identifications.forMedia('m1')).single.decision,
      IdentificationDecision.undecided,
    );
  });

  test('settling deleted photos drops their queued requests and waits for '
      'the running one', () async {
    engine.gate = Completer<void>();
    final a = service.request(photo('a'));
    await pumpEventQueue();
    final b = service.request(photo('b'));
    var settled = false;
    final settling = service.settle(['a', 'b']).then((_) => settled = true);
    await pumpEventQueue();
    expect(settled, isFalse);
    expect(service.isBusy('b'), isFalse);
    engine.gate!.complete();
    await Future.wait([a, b, settling]);
    // a finished before settle returned, so a purge after it removes all.
    expect(await identifications.runFor('a'), isNotNull);
    expect(await identifications.runFor('b'), isNull);
  });

  test('a dismissal records nothing if another logbook opened while it '
      'read', () async {
    await service.request(photo('m1'));
    final first = (await identifications.forMedia('m1')).single;
    final switching = MediaIdentificationService(
      engine: engine,
      loadPack: () async => installed,
      identifications: ReadHookRepository(library, () => generation++),
      embeddings: embeddings,
      crops: crops,
      resolveImage: (item) async => imageFor(item),
      taggedSpecies: (_) async => tagged,
      enabled: () => enabled,
      databaseGeneration: () => generation,
    );
    addTearDown(switching.dispose);
    await switching.reject('m1', [first.id]);
    expect(
      (await identifications.forMedia('m1')).single.decision,
      IdentificationDecision.undecided,
    );
  });

  test('a location that is not a number is treated as none', () async {
    await service.request(
      photo('m1'),
      location: const GeoPoint(double.nan, double.infinity),
    );
    final run = await identifications.runFor('m1');
    expect(run, isNotNull);
    expect(run!.locationCell, isNull);
  });

  group('memory readout', () {
    setUp(() async {
      await service.dispose();
      service = build(
        memoryReadout: MemoryReadout(engine: engine, enabled: () => true),
      );
    });

    test('a photo logs readings after load and after the photo', () async {
      await service.request(photo('m1'));
      expect(engine.events.take(4), [
        'load',
        'memory',
        'analyze:/photos/m1.jpeg',
        'memory',
      ]);
    });

    test('a photo given as bytes logs a reading after the photo', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      imageFor = (_) => IdentificationImage.bytes(bytes);
      await service.request(photo('m1'));
      expect(engine.analysedBytes, [bytes]);
      expect(engine.events.take(4), [
        'load',
        'memory',
        'analyze:bytes',
        'memory',
      ]);
    });

    test('a failing memory reading leaves the photo identified', () async {
      engine.memoryFailure = const VisionEngineException('unsupported');
      await service.request(photo('m1'));
      expect(await identifications.runFor('m1'), isNotNull);
      expect(
        await identifications.forMedia('m1'),
        hasLength(engine.embeddings.length),
      );
    });

    test('a slow memory reading does not hold up identification', () async {
      engine.memoryGate = Completer<void>();
      addTearDown(() => engine.memoryGate?.complete());
      await service.request(photo('m1')).timeout(const Duration(seconds: 5));
      expect(await identifications.runFor('m1'), isNotNull);
    });

    test('unloading logs a reading', () async {
      await service.request(photo('m1'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(engine.events.skip(engine.events.length - 2), [
        'unload',
        'memory',
      ]);
    });
  });
}
