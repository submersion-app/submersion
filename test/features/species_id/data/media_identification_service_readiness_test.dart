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
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'media_identification_service_fixtures.dart';

/// Records how the readiness check reads identifications.
class _SpyIdentifications extends MediaIdentificationRepository {
  _SpyIdentifications({super.database});

  final reads = <String>[];

  @override
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) {
    reads.add('snapshot${withPaths ? '+paths' : ''}');
    return super.forMediaIdsWithRuns(mediaIds, withPaths: withPaths);
  }
}

/// Which media a Find species run would find nothing to do on, by the rule
/// the service itself applies when it takes an item (issue #4727): what
/// the dive's card shows as all checked.
void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late _SpyIdentifications identifications;
  late MediaIdentificationService service;
  var deviceReads = 0;
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
    identifications = _SpyIdentifications(database: library);
    var ids = 0;
    deviceReads = 0;
    service = MediaIdentificationService(
      engine: FakeEngine(),
      loadPack: () async => pack(),
      identifications: identifications,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: IdentificationCropStore(supportPath: () async => support.path),
      resolveImage: (item) async =>
          IdentificationImage.path('/viewer/${item.id}.jpeg'),
      taggedSpecies: (_) async => const [],
      enabled: () => true,
      databaseGeneration: () => 0,
      now: () => DateTime.utc(2026, 11, 18),
      newId: () => 'id-${ids++}',
      deviceId: () async {
        deviceReads++;
        return 'phone';
      },
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

  test('rows the caller has read already are not read again (issue '
      '#4825)', () async {
    await lookAt(photo('m1'));
    final read = await identifications.forMediaIdsWithRuns([
      'm1',
    ], withPaths: false);
    identifications.reads.clear();
    expect(
      await service.upToDate(
        [photo('m1')],
        manifest: installed,
        locationOf: (_) => null,
        read: read,
      ),
      {'m1'},
    );
    expect(identifications.reads, isEmpty);
  });

  test('reads this device\'s id once for every item, not once each (issue '
      '#4876)', () async {
    await lookAt(photo('m1'));
    await lookAt(photo('m2'));
    deviceReads = 0;
    expect(await upToDate([photo('m1'), photo('m2')]), {'m1', 'm2'});
    expect(deviceReads, 1);
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

  test('a video scanned to its end by the installed pack and tracker is up '
      'to date', () async {
    await identifications.storeRun(
      MediaIdentificationRun(
        mediaId: 'v1',
        packVersion: installed.packVersion,
        // What a scan stores for a video: the detectors and the tracker.
        detectorId: videoRunDetectorId(installed.detectorSetId),
        classifierId: installed.classifier.embeddingId,
        analysedAt: DateTime.utc(2026, 11, 18),
        imageWidth: 1920,
        imageHeight: 1080,
        detectionCount: 0,
        scannedMs: 25000,
        videoDurationMs: 25000,
      ),
      insert: const [],
      deleteIds: const [],
    );

    expect(await upToDate([photo('v1', type: MediaType.video)]), {'v1'});
  });

  test('a video never scanned is not', () async {
    expect(await upToDate([photo('v1', type: MediaType.video)]), isEmpty);
  });

  test('only the media looked at are listed', () async {
    await lookAt(photo('m1'));
    expect(await upToDate([photo('m1'), photo('m2')]), {'m1'});
  });

  test('reads each media\'s run and rows in one snapshot, without track '
      'paths', () async {
    await lookAt(photo('m1'));
    identifications.reads.clear();

    await upToDate([photo('m1'), photo('v1', type: MediaType.video)]);

    expect(identifications.reads, ['snapshot']);
  });
}
