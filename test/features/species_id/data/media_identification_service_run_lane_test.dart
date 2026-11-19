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
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// A Find species run asks the service for a whole dive's media through a
/// lane of its own, behind whatever the viewer asks for (issue #4727).
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late FakeEngine engine;
  late bool viewerEnabled;
  late List<String> settled;
  late int generation;
  late MediaIdentificationService service;

  Future<IdentificationImage?> runImage(MediaItem item) async =>
      IdentificationImage.path('/run/${item.id}.jpeg');

  Future<RunItemOutcome> fromRun(MediaItem item) => service.requestFromRun(
    item,
    resolveImage: runImage,
    resolveVideo: (_) async => null,
  );

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_run');
    engine = FakeEngine();
    viewerEnabled = true;
    settled = [];
    generation = 0;
    var ids = 0;
    service = MediaIdentificationService(
      engine: engine,
      loadPack: () async => pack(),
      identifications: MediaIdentificationRepository(database: library),
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
      resolveImage: (item) async =>
          IdentificationImage.path('/viewer/${item.id}.jpeg'),
      taggedSpecies: (_) async => const [],
      enabled: () => viewerEnabled,
      runEnabled: () => true,
      databaseGeneration: () => generation,
      now: () => DateTime.utc(2026, 11, 18),
      newId: () => 'id-${ids++}',
      onItemSettled: (item, _) async => settled.add(item.id),
    );
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  test('a request made before another logbook opened is dropped, not '
      'analysed into the new one', () async {
    engine.gate = Completer<void>();
    final first = fromRun(photo('busy'));
    await pumpEventQueue();
    final queued = fromRun(photo('r1'));
    final viewer = service.request(photo('v1'));

    generation = 1;
    engine.gate!.complete();
    await Future.wait([first, viewer]);

    expect(await queued, RunItemOutcome.skipped);
    expect(engine.analysed, ['/run/busy.jpeg']);
  });

  test('a run analyses the image its own resolver gives', () async {
    expect(await fromRun(photo('m1')), RunItemOutcome.done);
    expect(engine.analysed, ['/run/m1.jpeg']);
  });

  test('a viewer request waiting goes before a waiting run request', () async {
    engine.gate = Completer<void>();
    final first = fromRun(photo('busy'));
    await pumpEventQueue();
    final run = fromRun(photo('r1'));
    final viewer = service.request(photo('v1'));
    engine.gate!.complete();
    await Future.wait([first, run, viewer]);
    expect(engine.analysed, [
      '/run/busy.jpeg',
      '/viewer/v1.jpeg',
      '/run/r1.jpeg',
    ]);
  });

  test('the viewer leaving a photo does not drop a run request', () async {
    engine.gate = Completer<void>();
    final first = fromRun(photo('busy'));
    await pumpEventQueue();
    final run = fromRun(photo('r1'));
    expect(service.cancelPending('r1'), isFalse);
    engine.gate!.complete();
    await first;
    expect(await run, RunItemOutcome.done);
  });

  test('cancelRun drops a queued run request', () async {
    engine.gate = Completer<void>();
    final first = fromRun(photo('busy'));
    await pumpEventQueue();
    final run = fromRun(photo('r1'));
    expect(service.cancelRun('r1'), isTrue);
    engine.gate!.complete();
    await first;
    expect(await run, RunItemOutcome.skipped);
    expect(engine.analysed, ['/run/busy.jpeg']);
  });

  test('served with identify-on-open off', () async {
    viewerEnabled = false;
    expect(await fromRun(photo('m1')), RunItemOutcome.done);
    expect(engine.analysed, hasLength(1));
  });

  test('an image that cannot be read is unreadable', () async {
    final outcome = await service.requestFromRun(
      photo('m1'),
      resolveImage: (_) async => null,
      resolveVideo: (_) async => null,
    );
    expect(outcome, RunItemOutcome.unreadable);
  });

  test('a video with no file is unreadable', () async {
    expect(
      await fromRun(photo('v1', type: MediaType.video)),
      RunItemOutcome.unreadable,
    );
  });

  test('a device too warm says so', () async {
    engine.failure = const VisionEngineException(VisionEngineException.tooHot);
    expect(await fromRun(photo('m1')), RunItemOutcome.tooHot);
  });

  test('a run item is not auto-applied on its own: the run applies them '
      'together', () async {
    await fromRun(photo('m1'));
    await service.request(photo('v1'));
    expect(settled, ['v1']);
  });
}
