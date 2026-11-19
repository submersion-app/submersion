import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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
    taggedSpecies: (mediaId) => identifications.taggedSpecies(mediaId),
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

  test('Remove on a row of two app tags takes the species and sighting the '
      'app created', () async {
    final own = await species.createSpecies(
      commonName: 'Creole Wrasse',
      scientificName: 'Clepticus parrae',
      category: SpeciesCategory.fish,
    );
    for (final (mediaId, created) in [('p1', true), ('p2', false)]) {
      await tagging.applyAppTag(
        mediaId: mediaId,
        speciesId: own.id,
        timing: SightingTiming.straightAway,
        createdSpecies: created,
      );
    }
    final groups = await load();
    final row = groups.single.tagged.firstWhere((r) => r.speciesId == own.id);

    await saver().save(
      SpeciesReviewEdits.none.decideRow(row, keep: false),
      groups,
    );

    expect(await species.getSpeciesById(own.id), isNull);
    final left = await species.getSightingsForDive('d1');
    expect(left.where((s) => s.speciesId == own.id), isEmpty);
  });

  group('a suggestion the app tagged while the decision was held', () {
    Future<SpeciesReviewEdits> heldOnSuggestion({required bool keep}) async {
      final row = (await load()).single.tagged.single;
      final suggested = row.items.singleWhere((i) => i.media.id == 'p2');
      final edits = SpeciesReviewEdits.none.decideItem(
        row,
        suggested,
        keep: keep,
      );
      // A Find species run, or a sync, applies the species to p2 meanwhile.
      await tagging.applyAppTag(
        mediaId: 'p2',
        speciesId: 'sp_queen_parrotfish',
        timing: SightingTiming.onConfirm,
        createdSpecies: false,
      );
      return edits;
    }

    test('a dismiss removes the app\'s tag', () async {
      final edits = await heldOnSuggestion(keep: false);
      final groups = await load();
      expect(
        groups.single.tagged.single.items
            .singleWhere((i) => i.media.id == 'p2')
            .isTagged,
        isTrue,
      );

      await saver().save(edits, groups);

      expect(await tags.findTag('p2', 'sp_queen_parrotfish'), isNull);
      expect(
        (await tags.findTag('p1', 'sp_queen_parrotfish'))!.unconfirmed,
        isTrue,
      );
    });

    test('an add confirms the app\'s tag', () async {
      final edits = await heldOnSuggestion(keep: true);

      await saver().save(edits, await load());

      expect(
        (await tags.findTag('p2', 'sp_queen_parrotfish'))!.unconfirmed,
        isFalse,
      );
    });
  });

  group('the app tagged the photo after the page last read it', () {
    Future<void> appTagsP2() => tagging.applyAppTag(
      mediaId: 'p2',
      speciesId: 'sp_queen_parrotfish',
      timing: SightingTiming.onConfirm,
      createdSpecies: false,
    );

    Future<(SpeciesReviewEdits, List<ReviewGroup>)> heldOnP2({
      required bool keep,
      required bool tagged,
    }) async {
      final stale = await load();
      final group = stale.single;
      final row = (tagged ? group.tagged : group.suggested).single;
      final item = row.items.singleWhere((i) => i.media.id == 'p2');
      return (SpeciesReviewEdits.none.decideItem(row, item, keep: keep), stale);
    }

    test('a held Dismiss removes the app\'s tag', () async {
      final (edits, stale) = await heldOnP2(keep: false, tagged: true);
      await appTagsP2();

      await saver().save(edits, stale);

      expect(await tags.findTag('p2', 'sp_queen_parrotfish'), isNull);
    });

    test('a held Remove leaves a tag confirmed elsewhere since: the '
        'diver\'s now', () async {
      final stale = await load();
      final row = stale.single.tagged.single;
      final appItem = row.items.singleWhere((i) => i.media.id == 'p1');
      final edits = SpeciesReviewEdits.none.decideItem(
        row,
        appItem,
        keep: false,
      );
      await tagging.confirmTag(mediaId: 'p1', speciesId: 'sp_queen_parrotfish');

      await saver().save(edits, stale);

      final tag = await tags.findTag('p1', 'sp_queen_parrotfish');
      expect(tag, isNotNull);
      expect(tag!.unconfirmed, isFalse);
    });

    test('a held Add confirms the app\'s tag', () async {
      final (edits, stale) = await heldOnP2(keep: true, tagged: true);
      await appTagsP2();

      await saver().save(edits, stale);

      expect(
        (await tags.findTag('p2', 'sp_queen_parrotfish'))!.unconfirmed,
        isFalse,
      );
    });

    test('a held Dismiss on a suggested species\' own row removes the '
        'app\'s tag', () async {
      await tagging.rejectTag(mediaId: 'p1', speciesId: 'sp_queen_parrotfish');
      final (edits, stale) = await heldOnP2(keep: false, tagged: false);
      await appTagsP2();

      await saver().save(edits, stale);

      expect(await tags.findTag('p2', 'sp_queen_parrotfish'), isNull);
    });
  });
}
