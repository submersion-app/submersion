import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../data/fake_vision_engine.dart';
import '../data/media_identification_service_fixtures.dart';

/// The dive card says all checked only when a Find species run would find
/// nothing to do, by the service's own rule (issue #4727): a run is the way
/// back for media whose crops are missing or whose place changed.
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late MediaIdentificationRepository identifications;
  late IdentificationCropStore crops;
  late MediaIdentificationService service;
  const reef = GeoPoint(12.1, -68.9);

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('dive_checked');
    identifications = MediaIdentificationRepository(database: library);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    var ids = 0;
    service = MediaIdentificationService(
      engine: FakeEngine(),
      loadPack: () async => pack(),
      identifications: identifications,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: crops,
      resolveImage: (item) async =>
          IdentificationImage.path('/viewer/${item.id}.jpeg'),
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
      now: () => DateTime.utc(2026, 11, 18),
      newId: () => 'id-${ids++}',
    );
  });
  tearDown(() async {
    await service.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  Future<void> lookAt(MediaItem item) async {
    final outcome = await service.requestFromRun(
      item,
      resolveImage: (i) async => IdentificationImage.path('/run/${i.id}.jpeg'),
      resolveVideo: (_) async => null,
    );
    expect(outcome, RunItemOutcome.done);
  }

  ProviderContainer containerFor({GeoPoint? entry}) {
    final container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(
          identifications,
        ),
        mediaIdentificationServiceProvider.overrideWithValue(service),
        identificationCropStoreProvider.overrideWithValue(crops),
        installedSpeciesPackProvider.overrideWith((ref) async => pack().pack),
        diveProvider('d1').overrideWith(
          (ref) async => domain.Dive(
            id: 'd1',
            dateTime: DateTime.utc(2026, 3, 9),
            entryLocation: entry,
          ),
        ),
        mediaForDiveProvider('d1').overrideWith((ref) async => [photo('m1')]),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(diveSpeciesCheckedProvider('d1'), (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  Future<bool> checked({GeoPoint? entry}) =>
      containerFor(entry: entry).read(diveSpeciesCheckedProvider('d1').future);

  test('a dive whose photos were all looked at here is checked', () async {
    await lookAt(photo('m1'));
    expect(await checked(), isTrue);
  });

  test('a dive whose crops are not on this device is not checked: a run '
      'brings them back after a restore', () async {
    await lookAt(photo('m1'));
    await for (final entry in support.list()) {
      await entry.delete(recursive: true);
    }
    expect(await checked(), isFalse);
  });

  test('a dive given a place since its run is not checked: a run names '
      'its photos for it', () async {
    await lookAt(photo('m1'));
    expect(await checked(entry: reef), isFalse);
  });

  test('crops that land after the rows are seen: an analysis stores its '
      'rows first', () async {
    await lookAt(photo('m1'));
    final ids = [for (final i in await identifications.forMedia('m1')) i.id];
    await for (final entry in support.list()) {
      await entry.delete(recursive: true);
    }
    final container = containerFor();
    expect(
      await container.read(diveSpeciesCheckedProvider('d1').future),
      isFalse,
    );

    for (final id in ids) {
      await crops.write('m1', id, Uint8List.fromList([0xFF, 0xD8]));
    }
    await pumpEventQueue();

    expect(
      await container.read(diveSpeciesCheckedProvider('d1').future),
      isTrue,
    );
  });
}
