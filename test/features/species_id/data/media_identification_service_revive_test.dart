import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/wait_until.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// Calls [onRead] before each read of an item's rows, once armed: the
/// first one after the diver leaves comes once the scan has decided to
/// stop, as it winds down.
class _ReadHookRepository extends MediaIdentificationRepository {
  _ReadHookRepository(AppDatabase database) : super(database: database);

  void Function()? onRead;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) {
    final hook = onRead;
    onRead = null;
    hook?.call();
    return super.forMedia(mediaId);
  }
}

/// Leaving a video while it is scanned, then coming back to it before the
/// scan has wound down (issue #4872): the request on coming back, by the
/// viewer or by hand from the labels menu, must see the video scanned.
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late _ReadHookRepository identifications;
  late FakeEngine engine;
  late MediaIdentificationService service;
  var ids = 0;
  var onOpen = true;

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_revive');
    identifications = _ReadHookRepository(library);
    engine = FakeEngine();
    ids = 0;
    onOpen = true;
    service = MediaIdentificationService(
      engine: engine,
      loadPack: () async => pack(),
      identifications: identifications,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
      resolveImage: (item) async =>
          IdentificationImage.path('/photos/${item.id}.jpeg'),
      resolveVideo: (item) async =>
          <T>(Future<T> Function(String path) read) =>
              read('/videos/${item.id}.mp4'),
      taggedSpecies: (_) async => const [],
      enabled: () => onOpen,
      runEnabled: () => true,
      databaseGeneration: () => 0,
      now: () => DateTime.utc(2026, 11, 22),
      newId: () => 'id-${ids++}',
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

  MediaItem video() => photo('v1', type: MediaType.video);

  /// A fish in view from 1 s to 4 s, named in pass 2 of the first chunk.
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

  test('coming back while the stopped scan winds down carries the scan on '
      'to the end', () async {
    oneFish();
    engine.videoGate = Completer<void>();
    final first = service.request(video());
    await waitUntil(() async => engine.detectCalls.length == 1);
    // The diver leaves: the scan stops at its next check.
    expect(service.cancelPending('v1'), isTrue);
    // And comes back once it has decided to stop, as it winds down.
    Future<void>? back;
    identifications.onRead = () {
      back = service.request(video());
    };
    engine.videoGate!.complete();
    engine.videoGate = null;
    await first;
    await waitUntil(() async => back != null);
    await back;
    await waitUntil(() async => !service.isBusy('v1'));
    expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
  });

  test('Analyse by hand while the stopped scan winds down carries the scan '
      'on to the end', () async {
    oneFish();
    engine.videoGate = Completer<void>();
    final first = service.request(video());
    await waitUntil(() async => engine.detectCalls.length == 1);
    expect(service.cancelPending('v1'), isTrue);
    Future<void>? analyse;
    identifications.onRead = () {
      analyse = service.request(video(), byHand: true);
    };
    engine.videoGate!.complete();
    engine.videoGate = null;
    await first;
    await waitUntil(() async => analyse != null);
    await analyse;
    await waitUntil(() async => !service.isBusy('v1'));
    expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
  });

  test('Analyse by hand joining a scan begun on opening carries it on '
      'after identify on opening is switched off', () async {
    oneFish();
    engine.videoGate = Completer<void>();
    final first = service.request(video());
    await waitUntil(() async => engine.detectCalls.length == 1);
    expect(service.cancelPending('v1'), isTrue);
    onOpen = false;
    Future<void>? analyse;
    identifications.onRead = () {
      analyse = service.request(video(), byHand: true);
    };
    engine.videoGate!.complete();
    engine.videoGate = null;
    await first;
    await waitUntil(() async => analyse != null);
    await analyse;
    await waitUntil(() async => !service.isBusy('v1'));
    expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
  });

  test('Analyse again while the stopped scan winds down scans the video '
      'from the start', () async {
    oneFish();
    engine.videoGate = Completer<void>();
    final first = service.request(video());
    await waitUntil(() async => engine.detectCalls.length == 1);
    expect(service.cancelPending('v1'), isTrue);
    Future<void>? again;
    identifications.onRead = () {
      again = service.request(video(), byHand: true, fresh: true);
    };
    engine.videoGate!.complete();
    engine.videoGate = null;
    await first;
    await waitUntil(() async => again != null);
    await again;
    await waitUntil(() async => !service.isBusy('v1'));
    expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    // Scanned again from the start after the stopped one.
    expect(engine.detectCalls.where((c) => c.$1 == 0), hasLength(2));
  });

  test('a photo left while it is analysed is stored, and Analyse by hand '
      'and Analyse again both run on coming back', () async {
    final first = service.request(photo('p1'));
    // Leaving a photo being analysed never drops it.
    expect(service.cancelPending('p1'), isFalse);
    await first;
    expect(await identifications.runFor('p1'), isNotNull);
    expect(engine.analysed, hasLength(1));

    await service.request(photo('p1'), byHand: true);
    // Up to date: nothing to analyse again.
    expect(engine.analysed, hasLength(1));

    await service.request(photo('p1'), byHand: true, fresh: true);
    expect(engine.analysed, hasLength(2));
  });
}
