import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// The service hands each item to auto-apply once it is settled: analysed,
/// renamed, found to need nothing, or with no model installed, where the
/// stored names still count (issue #4727).
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late LoadedPack? installed;
  late List<String> settled;
  late MediaIdentificationService service;

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_apply');
    installed = pack();
    settled = [];
    var ids = 0;
    service = MediaIdentificationService(
      engine: FakeEngine(),
      loadPack: () async => installed,
      identifications: MediaIdentificationRepository(database: library),
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
      resolveImage: (item) async =>
          IdentificationImage.path('/photos/${item.id}.jpeg'),
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
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

  test('after an analysis, and again when it needs nothing', () async {
    await service.request(photo('m1'));
    await service.request(photo('m1'));
    expect(settled, ['m1', 'm1']);
  });

  test('with no model installed, the stored names still count', () async {
    installed = null;
    await service.request(photo('m1'));
    expect(settled, ['m1']);
  });

  test('not for media that is neither a photo nor a video', () async {
    await service.request(photo('d1', type: MediaType.document));
    expect(settled, isEmpty);
  });
}
