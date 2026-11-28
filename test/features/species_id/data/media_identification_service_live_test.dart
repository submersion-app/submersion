import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// Naming what a camera sees, and the pack the Identify viewer shares
/// (issue #5122).
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late FakeEngine engine;
  late MediaIdentificationService service;
  late LoadedPack installed;
  var packLoads = 0;

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_live');
    engine = FakeEngine();
    installed = pack();
    packLoads = 0;
    service = MediaIdentificationService(
      engine: engine,
      loadPack: () async {
        packLoads++;
        return installed;
      },
      identifications: MediaIdentificationRepository(database: library),
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
      resolveImage: (_) async => null,
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
    );
  });

  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  test('live naming loads the models dropped behind its hold again', () async {
    final live = (await service.liveNaming())!;
    // An iOS memory warning drops the models without asking.
    engine.loaded = false;

    final analysis = await live.analyze(frame);

    expect(analysis.detections, isNotEmpty);
    expect(engine.loads, hasLength(2));
    service.releaseLiveNaming();
  });

  test('the pack is loaded once and shared', () async {
    final first = await service.loadedPack();
    final second = await service.loadedPack();

    expect(first, same(installed));
    expect(second, same(first));
    expect(packLoads, 1);
  });
}
