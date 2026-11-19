import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
import 'package:submersion/features/species_id/data/services/species_review_saver.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';
import 'identification_fixtures.dart';

/// Saving Species to review: everything decided, as one History entry
/// (issue #4727).
void main() {
  late AppDatabase db;
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;
  late SpeciesTaggingService tagging;
  late MediaIdentificationRepository identifications;
  late List<(String, List<String>)> dismissed;
  final changeLog = ChangeLogRepository();

  SpeciesReviewSaver saver() => SpeciesReviewSaver(
    tagging: tagging,
    acceptor: SuggestionAcceptor(species: species),
    dismiss: (mediaId, ids) async => dismissed.add((mediaId, ids)),
    reconcile: (_) async {},
  );

  Future<List<ReviewGroup>> load() => SpeciesReviewRepository(
    tags: tags,
    identifications: identifications,
    media: MediaRepository(),
    species: species,
    dives: DiveRepository(),
  ).load(const DiveReviewScope('d1'), withSuggestions: true);

  setUp(() async {
    db = await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    identifications = MediaIdentificationRepository();
    tagging = SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: species,
    );
    dismissed = [];
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await tagging.applyAppTag(
      mediaId: 'p1',
      speciesId: 'sp_queen_parrotfish',
      timing: SightingTiming.onConfirm,
      createdSpecies: false,
    );
    await identifications.storeRun(
      run(mediaId: 'p2'),
      insert: [identification('i-p2', mediaId: 'p2')],
      deleteIds: const [],
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('Confirm on the mixed row: the tag confirmed with its sighting, the '
      'suggested photo tagged, as one operation', () async {
    final groups = await load();
    final row = groups.single.tagged.single;

    await saver().save(
      SpeciesReviewEdits.none.decideRow(row, keep: true),
      groups,
    );

    expect(
      (await tags.findTag('p1', 'sp_queen_parrotfish'))!.unconfirmed,
      isFalse,
    );
    final added = await tags.findTag('p2', 'sp_queen_parrotfish');
    expect(added, isNotNull);
    expect(added!.unconfirmed, isFalse);
    expect(await species.getSightingsForDive('d1'), hasLength(1));
    await changeLog.settleAll();
    final ops = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label = 'species_review'",
        )
        .get();
    expect(ops, hasLength(1));
  });

  test('Remove on the mixed row: the tag removed, the suggestion '
      'dismissed', () async {
    final groups = await load();
    final row = groups.single.tagged.single;

    await saver().save(
      SpeciesReviewEdits.none.decideRow(row, keep: false),
      groups,
    );

    expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
    expect(dismissed.single.$1, 'p2');
    expect(dismissed.single.$2, ['i-p2']);
  });
}
