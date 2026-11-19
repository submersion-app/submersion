import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/auto_applier.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';
import 'identification_fixtures.dart';

/// Tagging confident matches with no tap (issue #4727).
void main() {
  late AppDatabase db;
  late MediaIdentificationRepository identifications;
  late MediaSpeciesRepository tags;
  late SpeciesRepository species;
  var autoApply = true;
  final changeLog = ChangeLogRepository();

  AutoApplier applier() => AutoApplier(
    identifications: identifications,
    acceptor: SuggestionAcceptor(species: species),
    tagging: SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: species,
    ),
    enabled: () => autoApply,
    timing: () => SightingTiming.onConfirm,
  );

  Future<void> store(String mediaId, {bool confident = true}) =>
      identifications.storeRun(
        run(mediaId: mediaId),
        insert: [
          identification(
            'i-$mediaId',
            mediaId: mediaId,
          ).copyWith(confident: confident),
        ],
        deleteIds: const [],
      );

  setUp(() async {
    db = await setUpTestDatabase();
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    autoApply = true;
    identifications = MediaIdentificationRepository();
    tags = MediaSpeciesRepository();
    species = SpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('tags a confident species, unconfirmed, and accepts the crop', () async {
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    await store('p1');

    expect(await applier().applyInScope('p1', isVideo: false), 1);

    final tag = await tags.findTag('p1', 'sp_queen_parrotfish');
    expect(tag!.unconfirmed, isTrue);
    expect(tag.createdSpecies, isFalse);
    final row = (await identifications.forMedia('p1')).single;
    expect(row.decision, IdentificationDecision.accepted);
  });

  test('records the species it had to create', () async {
    await store('p1');

    await applier().applyInScope('p1', isVideo: false);

    final created = await species.findSpeciesByScientificName('Scarus vetula');
    final tag = await tags.findTag('p1', created!.id);
    expect(tag!.createdSpecies, isTrue);
  });

  test('nothing when it is not confident', () async {
    await store('p1', confident: false);
    expect(await applier().applyInScope('p1', isVideo: false), 0);
    expect(await tags.getTagsForMedia('p1'), isEmpty);
  });

  test('nothing with the setting off', () async {
    autoApply = false;
    await store('p1');
    expect(await applier().applyInScope('p1', isVideo: false), 0);
  });

  test('nothing with the feature off', () async {
    marineLifeIdEnabled = false;
    await store('p1');
    expect(await applier().applyInScope('p1', isVideo: false), 0);
  });

  test(
    'one change log operation, labelled marine life identification',
    () async {
      await store('p1');

      await applier().applyInScope('p1', isVideo: false);

      await changeLog.settleAll();
      final ops = await db
          .customSelect('SELECT source, label FROM change_log_operations')
          .get();
      expect(
        [for (final o in ops) o.data],
        [
          {'source': 'automatic', 'label': 'marine_life_id'},
        ],
      );
    },
  );
}
