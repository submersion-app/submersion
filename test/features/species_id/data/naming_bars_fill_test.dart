import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_sync_marks.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/naming_bars_fill.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../domain/manifest_fixture.dart';
import 'identification_fixtures.dart';

/// A throwing sync repository: what a write's publishing meets when the
/// logbook cannot be marked.
class _BrokenSync implements SyncRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(StateError('no sync'));
}

/// A sweep that records when it runs.
class _RecordingCleanup extends IdentificationCleanup {
  _RecordingCleanup(
    this.steps, {
    required super.identifications,
    required super.embeddings,
    required super.crops,
  });

  final List<String> steps;

  @override
  Future<int> sweepOrphans() async {
    steps.add('sweep');
    return super.sweepOrphans();
  }
}

/// A crop store that records when the backfill looks for files to move.
class _RecordingCrops extends IdentificationCropStore {
  _RecordingCrops(this.steps, {required super.supportPath, super.table});

  final List<String> steps;

  @override
  Future<List<String>> mediaWithFiles() async {
    steps.add('backfill');
    return super.mediaWithFiles();
  }
}

/// The launch steps that bring this device's results from before sync up
/// to date (issue #4876): naming bars on old runs, named crops into the
/// logbook.
void main() {
  late AppDatabase db;
  late MediaIdentificationRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    repo = MediaIdentificationRepository(database: db);
  });
  tearDown(() => db.close());

  final manifest = SpeciesPackManifest.parse(manifestJson());
  InstalledPack installed() => InstalledPack(
    manifest: manifest,
    directory: '/pack',
    detectorPaths: const ['/pack/det'],
    classifierPath: '/pack/clf',
  );

  group('fillNamingBarsFromInstalledPack', () {
    test('gives this device\'s runs of the installed pack its bars', () async {
      await repo.storeRun(
        run().copyWith(packVersion: manifest.packVersion),
        insert: const [],
        deleteIds: const [],
      );
      final filled = await fillNamingBarsFromInstalledPack(
        installed: () async => installed(),
        identifications: repo,
        deviceId: () async => 'laptop',
      );
      expect(filled, 1);
      expect(
        (await repo.runFor('m1'))!.namingBars,
        NamingBars.fromNaming(manifest.naming),
      );
    });

    test('does nothing with no pack installed', () async {
      expect(
        await fillNamingBarsFromInstalledPack(
          installed: () async => null,
          identifications: repo,
          deviceId: () async => null,
        ),
        0,
      );
    });

    test('never throws', () async {
      expect(
        await fillNamingBarsFromInstalledPack(
          installed: () async => throw StateError('unreadable'),
          identifications: repo,
          deviceId: () async => null,
        ),
        0,
      );
    });
  });

  group('the launch steps', () {
    late Directory support;
    late ProviderContainer container;

    setUp(() async {
      support = await Directory.systemTemp.createTemp('launch_steps');
      container = ProviderContainer(
        overrides: [
          mediaIdentificationRepositoryProvider.overrideWithValue(repo),
          speciesPackStoreProvider.overrideWithValue(
            SpeciesPackStore(
              supportPath: () async => support.path,
              engine: 'none',
            ),
          ),
          identificationCropStoreProvider.overrideWithValue(
            IdentificationCropStore(
              supportPath: () async => support.path,
              table: IdentificationCropRepository(database: db),
            ),
          ),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await deleteTempDir(support);
    });

    test('do nothing where the models cannot run', () async {
      marineLifeIdEnabled = false;
      addTearDown(resetMarineLifeIdEnabled);
      await container
          .read(identificationCropStoreProvider)
          .write('m1', 'a', Uint8List.fromList([1]));
      await repo.storeRun(
        run(),
        insert: [identification('a')],
        deleteIds: const [],
      );
      await fillIdentificationNamingBarsAtLaunch(container);
      await backfillNamedCropsAtLaunch(container);
      expect(
        await IdentificationCropRepository(database: db).bytesFor('a'),
        isNull,
      );
    });

    test(
      'run where they can: named crop files move into the logbook',
      () async {
        marineLifeIdEnabled = true;
        addTearDown(resetMarineLifeIdEnabled);
        await repo.storeRun(
          run(),
          insert: [identification('a')],
          deleteIds: const [],
        );
        await container
            .read(identificationCropStoreProvider)
            .write('m1', 'a', Uint8List.fromList([1]));
        await fillIdentificationNamingBarsAtLaunch(container);
        await backfillNamedCropsAtLaunch(container);
        expect(await IdentificationCropRepository(database: db).bytesFor('a'), [
          1,
        ]);
      },
    );
  });

  test('at launch the orphan sweep runs before the crop backfill, so a crop '
      'of media being purged is never moved into the logbook', () async {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    final support = await Directory.systemTemp.createTemp('launch_order');
    addTearDown(() => deleteTempDir(support));
    final local = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(local.close);
    final steps = <String>[];
    final crops = _RecordingCrops(
      steps,
      supportPath: () async => support.path,
      table: IdentificationCropRepository(database: db),
    );
    addTearDown(crops.dispose);
    // Made here, its media gone: an orphan, with a named crop still a file.
    await repo.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    await crops.write('m1', 'a', Uint8List.fromList([1]));
    final container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(repo),
        speciesPackStoreProvider.overrideWithValue(
          SpeciesPackStore(
            supportPath: () async => support.path,
            engine: 'none',
          ),
        ),
        identificationCropStoreProvider.overrideWithValue(crops),
        identificationCleanupProvider.overrideWithValue(
          _RecordingCleanup(
            steps,
            identifications: repo,
            embeddings: IdentificationEmbeddingRepository(database: local),
            crops: crops,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await runIdentificationLaunchSteps(container);

    expect(steps, ['sweep', 'backfill']);
    expect(await repo.runFor('m1'), isNull);
    expect(
      await IdentificationCropRepository(database: db).bytesFor('a'),
      isNull,
    );
  });

  test(
    'a write whose publishing fails still lands, and nothing throws',
    () async {
      final broken = MediaIdentificationRepository(
        database: db,
        marks: IdentificationSyncMarks(sync: _BrokenSync()),
      );
      await broken.storeRun(
        run(),
        insert: [identification('a')],
        deleteIds: const ['gone'],
      );
      await broken.claim('a', 'sp1');
      expect((await broken.forMedia('m1')).single.claimedSpeciesId, 'sp1');
    },
  );
}
