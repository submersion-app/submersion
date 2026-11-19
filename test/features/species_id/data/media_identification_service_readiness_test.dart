import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// Which media a Find species run would find nothing to do on, by the rule
/// the service itself applies when it takes an item (issue #4727): what
/// the dive's card shows as all checked.
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late MediaIdentificationService service;
  final installed = pack().pack.manifest;
  const reef = GeoPoint(12.1, -68.9);

  Future<void> lookAt(MediaItem item, {GeoPoint? location}) async {
    final outcome = await service.requestFromRun(
      item,
      location: location,
      resolveImage: (i) async => IdentificationImage.path('/run/${i.id}.jpeg'),
      resolveVideo: (_) async => null,
    );
    expect(outcome, RunItemOutcome.done);
  }

  Future<Set<String>> upToDate(
    List<MediaItem> items, {
    SpeciesPackManifest? manifest,
    GeoPoint? location,
  }) => service.upToDate(
    items,
    manifest: manifest ?? installed,
    locationOf: (_) => location,
  );

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('identification_ready');
    var ids = 0;
    service = MediaIdentificationService(
      engine: FakeEngine(),
      loadPack: () async => pack(),
      identifications: MediaIdentificationRepository(database: library),
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
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

  test('a photo looked at with the installed pack, its crops here, is up '
      'to date', () async {
    await lookAt(photo('m1'));
    expect(await upToDate([photo('m1')]), {'m1'});
  });

  test('a photo never looked at is not', () async {
    expect(await upToDate([photo('m1')]), isEmpty);
  });

  test('a photo whose crops are not on this device is not: a restore '
      'brings the rows, not the crops', () async {
    await lookAt(photo('m1'));
    await for (final entry in support.list()) {
      await entry.delete(recursive: true);
    }
    expect(await upToDate([photo('m1')]), isEmpty);
  });

  test('a photo named for another place is not: the dive got a site '
      'since', () async {
    await lookAt(photo('m1'));
    expect(await upToDate([photo('m1')], location: reef), isEmpty);
  });

  test('a photo named at the place it is still at is up to date', () async {
    await lookAt(photo('m1'), location: reef);
    expect(await upToDate([photo('m1')], location: reef), {'m1'});
  });

  test('a photo looked at with another pack is not', () async {
    await lookAt(photo('m1'));
    final newer = pack(version: '2026.12.1').pack.manifest;
    expect(await upToDate([photo('m1')], manifest: newer), isEmpty);
  });

  test('a video never scanned is not', () async {
    expect(await upToDate([photo('v1', type: MediaType.video)]), isEmpty);
  });

  test('only the media looked at are listed', () async {
    await lookAt(photo('m1'));
    expect(await upToDate([photo('m1'), photo('m2')]), {'m1'});
  });
}
