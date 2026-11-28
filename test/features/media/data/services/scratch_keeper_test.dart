import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/data/services/scratch_keeper.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

import '../../../../helpers/test_database.dart';
import '../../../species_id/data/identification_fixtures.dart';
import '../repositories/species_photo_fixtures.dart';

/// Keeping a file from the Identify viewer (issue #5122).
void main() {
  late AppDatabase logbook;
  late ScratchSession session;
  late Directory supportDir;
  late IdentificationCropStore realCrops;
  late ScratchKeeper keeper;
  final linked = <String>[];
  final enqueued = <String>[];
  final gone = <String>{};

  MediaItem scratchItem(String id) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: '/clips/$id.jpg',
    originalFilename: 'GX0102.JPG',
    takenAt: DateTime.utc(2026, 11, 1),
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );

  final a = ScratchSession.newId();
  final b = ScratchSession.newId();
  const stoplight = PackCandidate(
    gbifKey: 5,
    scientificName: 'Sparisoma viride',
    commonName: 'Stoplight Parrotfish',
    category: SpeciesCategory.fish,
  );

  setUp(() async {
    logbook = await setUpTestDatabase();
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    session = await ScratchSession.open(
      source: logbook,
      items: [scratchItem(a), scratchItem(b)],
    );
    supportDir = await Directory.systemTemp.createTemp('keeper_support_');
    addTearDown(() => supportDir.delete(recursive: true));
    realCrops = IdentificationCropStore(
      supportPath: () async => supportDir.path,
      table: IdentificationCropRepository(),
    );
    linked.clear();
    enqueued.clear();
    gone.clear();
    keeper = ScratchKeeper(
      session: session,
      media: MediaRepository(),
      identifications: MediaIdentificationRepository(),
      embeddings: IdentificationEmbeddingRepository(),
      crops: realCrops,
      species: SpeciesRepository(),
      tagging: SpeciesTaggingService(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      ),
      onMediaCreated: enqueued.add,
      linkFile: (item) async {
        if (gone.contains(item.id)) {
          throw ScratchFileGone(item.originalFilename!);
        }
        linked.add(item.id);
        return item;
      },
    );
  });

  tearDown(() async {
    await session.dispose();
    await tearDownTestDatabase();
  });

  /// What the session found on [id]: a run, a crop, and a species the
  /// catalogue lacked, accepted.
  Future<String> analyse(String id) async {
    await MediaIdentificationRepository(database: session.logbook).storeRun(
      run(mediaId: id),
      insert: [identification('i-$id', mediaId: id)],
      deleteIds: const [],
    );
    await IdentificationCropStore(
      supportPath: () async => session.cropRoot.path,
      table: IdentificationCropRepository(database: session.logbook),
    ).write(id, 'i-$id', Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]));
    final created = await SuggestionAcceptor(
      species: SpeciesRepository(database: session.logbook),
    ).resolve(stoplight);
    return created.id;
  }

  SpeciesTagChip chip(String speciesId) => SpeciesTagChip(
    speciesId: speciesId,
    storedName: 'Stoplight Parrotfish',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  test(
    'keeping with no place copies the row, results, crop and species',
    () async {
      final speciesId = await analyse(a);

      final result = await keeper.keep(
        [a],
        const UnplacedAttachTarget(),
        {
          a: [chip(speciesId)],
        },
      );

      final newId = result.keptIds[a]!;
      final row = (await MediaRepository().getMediaById(newId))!;
      expect(row.retainInLibrary, isTrue);
      expect(row.diveId, isNull);
      expect(row.siteId, isNull);
      final identifications = MediaIdentificationRepository();
      expect(await identifications.runFor(newId), isNotNull);
      expect((await identifications.forMedia(newId)).map((i) => i.id), [
        'i-$a',
      ]);
      expect(await realCrops.read(newId, 'i-$a'), isNotNull);
      final species = await SpeciesRepository().getSpeciesById(speciesId);
      expect(species!.commonName, 'Stoplight Parrotfish');
      expect(
        await MediaSpeciesRepository().findTag(newId, speciesId),
        isNotNull,
      );
    },
  );

  test('a species the logbook lacks is created only when kept', () async {
    final speciesId = await analyse(a);

    expect(await SpeciesRepository().getSpeciesById(speciesId), isNull);
    await keeper.keep(
      [a],
      const UnplacedAttachTarget(),
      {
        a: [chip(speciesId)],
      },
    );
    expect(await SpeciesRepository().getSpeciesById(speciesId), isNotNull);
  });

  test('keeping on a dive turns a tag into the dive\'s sighting', () async {
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd1', at: DateTime(2026, 11, 1), siteId: 's1');

    await keeper.keep(
      [a],
      const DiveAttachTarget('d1'),
      {
        a: [chip('sp_queen_parrotfish')],
      },
    );

    final sightings = await SpeciesRepository().getSightingsForDive('d1');
    expect(sightings.map((s) => s.speciesId), ['sp_queen_parrotfish']);
  });

  test('keeping on a site places the row there', () async {
    await insertTestSite('s1', 'Blue Hole');

    final result = await keeper.keep([a], const SiteAttachTarget('s1'), {});

    final row = (await MediaRepository().getMediaById(result.keptIds[a]!))!;
    expect(row.siteId, 's1');
    expect(row.retainInLibrary, isFalse);
  });

  test(
    'a kept file is queued for the media store; a failed one is not',
    () async {
      final result = await keeper.keep([a], const UnplacedAttachTarget(), {});
      await keeper.keep(
        [b],
        const UnplacedAttachTarget(),
        {
          b: [chip('sp_nowhere')],
        },
      );

      expect(enqueued, [result.keptIds[a]]);
    },
  );

  test('keeping twice makes one row', () async {
    await keeper.keep([a], const UnplacedAttachTarget(), {});
    final again = await keeper.keep([a], const UnplacedAttachTarget(), {});

    expect(again.keptIds, isEmpty);
    expect(linked, [a]);
  });

  test('a keep that fails part way leaves no row behind', () async {
    // A tag of a species neither logbook has fails after the row is in.
    final result = await keeper.keep(
      [a],
      const UnplacedAttachTarget(),
      {
        a: [chip('sp_nowhere')],
      },
    );

    expect(result.failures.keys, [a]);
    final rows = await logbook
        .customSelect('SELECT COUNT(*) AS n FROM media')
        .getSingle();
    expect(rows.read<int>('n'), 0);
    expect(session.isKept(a), isFalse);
  });

  test('a file gone from disk fails alone', () async {
    gone.add(a);

    final result = await keeper.keep([a, b], const UnplacedAttachTarget(), {});

    expect(result.failures[a], isA<ScratchFileGone>());
    expect(result.keptIds.keys, [b]);
  });

  test('nothing is copied into the logbook before keeping', () async {
    await analyse(a);

    final rows = await logbook
        .customSelect('SELECT COUNT(*) AS n FROM media_identifications')
        .getSingle();
    expect(rows.read<int>('n'), 0);
  });
}
