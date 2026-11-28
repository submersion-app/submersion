import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/scratch/scratch_scope.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';
import '../../data/identification_fixtures.dart';

/// Species identification on a file the diver has not kept writes only to
/// the Identify session, never to the logbook (issue #5122).
void main() {
  late AppDatabase logbook;
  late ScratchSession session;
  late ProviderContainer root;
  late ProviderContainer scratch;
  final id = ScratchSession.newId();

  /// Rows in every table a scratch action could reach, and the logs that
  /// record a write.
  const watched = [
    'media',
    'media_species',
    'species',
    'sightings',
    'media_identification_runs',
    'media_identifications',
    'media_identification_crops',
    'sync_records',
    'change_log_events',
    'deletion_log',
  ];

  Future<Map<String, int>> counts(AppDatabase db) async => {
    for (final table in watched)
      table:
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM $table')
                  .getSingle())
              .read<int>('n'),
  };

  setUp(() async {
    logbook = await setUpTestDatabase();
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    session = await ScratchSession.open(
      source: logbook,
      items: [
        MediaItem(
          id: id,
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          localPath: '/clips/GX010245.JPG',
          takenAt: DateTime.utc(2026, 11, 1),
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
      ],
    );
    root = ProviderContainer(
      overrides: [
        installedSpeciesPackProvider.overrideWith((ref) async => null),
      ],
    );
    scratch = ProviderContainer(
      parent: root,
      overrides: scratchOverrides(session),
    );
  });

  tearDown(() async {
    scratch.dispose();
    root.dispose();
    await session.dispose();
    await tearDownTestDatabase();
  });

  const unknown = PackCandidate(
    gbifKey: 5,
    scientificName: 'Sparisoma viride',
    commonName: 'Stoplight Parrotfish',
    category: SpeciesCategory.fish,
  );

  test('the copy of the catalogue names the diver\'s own species', () async {
    final species = await scratch.read(allSpeciesProvider.future);

    expect(species.map((s) => s.id), contains('sp_queen_parrotfish'));
  });

  test('no scratch action writes to the logbook', () async {
    final before = await counts(logbook);

    final identifications = scratch.read(mediaIdentificationRepositoryProvider);
    await identifications.storeRun(
      run(mediaId: id, count: 2),
      insert: [
        identification('i1', mediaId: id),
        identification('i2', mediaId: id),
      ],
      deleteIds: const [],
    );
    await scratch
        .read(identificationCropStoreProvider)
        .write(id, 'i1', Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]));
    // Accepting a suggestion the catalogue lacks creates the species.
    final created = await scratch
        .read(suggestionAcceptorProvider)
        .resolve(unknown);
    final tagging = scratch.read(speciesTaggingServiceProvider);
    await tagging.tagPhoto(mediaId: id, speciesId: created.id);
    await tagging.applyAppTag(
      mediaId: id,
      speciesId: 'sp_queen_parrotfish',
      timing: SightingTiming.straightAway,
      createdSpecies: false,
    );
    await tagging.confirmTag(mediaId: id, speciesId: 'sp_queen_parrotfish');
    await identifications.updateDecisions([
      identification(
        'i2',
        mediaId: id,
        decision: IdentificationDecision.rejected,
        decidedAt: fixtureT1,
      ),
    ]);
    await tagging.rejectTag(mediaId: id, speciesId: created.id);

    expect(await counts(logbook), before);
  });

  test('the overlays read the session', () async {
    await scratch
        .read(mediaIdentificationRepositoryProvider)
        .storeRun(
          run(mediaId: id),
          insert: [identification('i1', mediaId: id)],
          deleteIds: const [],
        );
    final created = await scratch
        .read(suggestionAcceptorProvider)
        .resolve(unknown);
    await scratch
        .read(speciesTaggingServiceProvider)
        .tagPhoto(mediaId: id, speciesId: created.id);

    expect(
      await scratch.read(photoDetectionsProvider(id).future),
      hasLength(1),
    );
    final chips = await scratch.read(mediaTagChipsProvider(id).future);
    expect(chips.map((c) => c.speciesId), [created.id]);
    expect(
      (await scratch.read(speciesProvider(created.id).future))!.commonName,
      'Stoplight Parrotfish',
    );
    // The diver's own logbook never heard of either.
    expect(await root.read(mediaTagChipsProvider(id).future), isEmpty);
    expect(await root.read(speciesProvider(created.id).future), isNull);
  });

  test('closing the session deletes its crops', () async {
    await scratch
        .read(identificationCropStoreProvider)
        .write(id, 'i1', Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]));
    expect(await session.cropRoot.exists(), isTrue);

    scratch.dispose();
    await session.dispose();

    expect(await session.cropRoot.exists(), isFalse);
  });
}
