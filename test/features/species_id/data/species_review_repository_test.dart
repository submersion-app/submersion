import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';
import 'identification_fixtures.dart';

/// Records how the review reads identifications.
class _SpyIdentifications extends MediaIdentificationRepository {
  final reads = <String>[];

  @override
  Future<Map<String, MediaIdentificationRun>> runsFor(List<String> mediaIds) {
    reads.add('runs');
    return super.runsFor(mediaIds);
  }

  @override
  Future<Map<String, List<MediaIdentification>>> forMediaIds(
    List<String> mediaIds, {
    bool withPaths = true,
  }) {
    reads.add('rows${withPaths ? '+paths' : ''}');
    return super.forMediaIds(mediaIds, withPaths: withPaths);
  }

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

/// Gathering what Species to review shows, for a dive or the log (issue
/// #4727).
void main() {
  late SpeciesReviewRepository review;
  late MediaSpeciesRepository tags;
  late MediaIdentificationRepository identifications;

  setUp(() async {
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    identifications = MediaIdentificationRepository();
    review = SpeciesReviewRepository(
      tags: tags,
      identifications: identifications,
      media: MediaRepository(),
      species: SpeciesRepository(),
      dives: DiveRepository(),
    );
    await insertTestDiver('me');
    await insertTestDiver('other');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'me');
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11), diverId: 'me');
    await insertTestSpecies(id: 'sp_blue_tang', name: 'Blue Tang');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'q1', diveId: 'd2');
    await tags.addTag(
      mediaId: 'p1',
      speciesId: 'sp_blue_tang',
      unconfirmed: true,
    );
    await tags.addTag(
      mediaId: 'q1',
      speciesId: 'sp_blue_tang',
      unconfirmed: true,
    );
    await identifications.storeRun(
      run(mediaId: 'p2'),
      insert: [identification('i-p2', mediaId: 'p2')],
      deleteIds: const [],
    );
  });

  tearDown(tearDownTestDatabase);

  test('a dive: its unconfirmed tags and its suggestions', () async {
    final groups = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
    );
    final g = groups.single;
    expect(g.diveId, 'd1');
    expect(g.tagged.single.speciesId, 'sp_blue_tang');
    expect(g.suggested.single.candidate!.scientificName, 'Scarus vetula');
  });

  /// An accepted identification on p1 for [speciesId]: the fixture's
  /// candidates, Queen Parrotfish (2393681, 0.9) then Stoplight Parrotfish
  /// (5, 0.05).
  Future<void> acceptedOnP1(String speciesId) => identifications.storeRun(
    run(mediaId: 'p1'),
    insert: [
      identification(
        'i-p1',
        mediaId: 'p1',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: speciesId,
      ),
    ],
    deleteIds: const [],
  );

  ReviewItem tagItem(List<ReviewGroup> groups, String speciesId) => groups
      .single
      .tagged
      .singleWhere((r) => r.speciesId == speciesId)
      .items
      .single;

  test('an app tag carries the key and score of its own species, not the '
      'top name\'s', () async {
    // A species outside the catalogue, named by its scientific name. The
    // diver's correction (or a re-name) left it second on the crop.
    final db = DatabaseService.instance.database;
    await db
        .into(db.species)
        .insert(
          const SpeciesCompanion(
            id: Value('own-stoplight'),
            commonName: Value('Stoplight Parrotfish'),
            scientificName: Value('Sparisoma viride'),
            category: Value('fish'),
            isBuiltIn: Value(false),
          ),
        );
    await tags.addTag(
      mediaId: 'p1',
      speciesId: 'own-stoplight',
      unconfirmed: true,
    );
    await acceptedOnP1('own-stoplight');

    final item = tagItem(
      await review.load(const DiveReviewScope('d1'), withSuggestions: true),
      'own-stoplight',
    );

    expect(item.cropIdentificationId, 'i-p1');
    expect(item.tagGbifKey, 5);
    expect(item.score, 0.05);
  });

  test('a tag whose identification no longer lists its species has no key '
      'or score, only its crop', () async {
    await acceptedOnP1('sp_blue_tang');

    final item = tagItem(
      await review.load(const DiveReviewScope('d1'), withSuggestions: true),
      'sp_blue_tang',
    );

    expect(item.cropIdentificationId, 'i-p1');
    expect(item.tagGbifKey, isNull);
    expect(item.score, isNull);
  });

  test(
    'with no crop that lists the species, the clearest crop shows it',
    () async {
      // Two crops behind the Blue Tang tag, neither naming it any more; the
      // second named its own species far more surely.
      final weak = identification(
        'i-a',
        mediaId: 'p1',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_blue_tang',
      );
      await identifications.storeRun(
        run(mediaId: 'p1', count: 2),
        insert: [
          weak.copyWith(
            candidates: [
              for (final c in weak.candidates)
                NamedCandidate(candidate: c.candidate, score: c.score / 4),
            ],
          ),
          identification(
            'i-b',
            mediaId: 'p1',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_blue_tang',
          ),
        ],
        deleteIds: const [],
      );

      final item = tagItem(
        await review.load(const DiveReviewScope('d1'), withSuggestions: true),
        'sp_blue_tang',
      );

      expect(item.cropIdentificationId, 'i-b');
    },
  );

  test('the log: every dive with something to review', () async {
    final groups = await review.load(
      const LogReviewScope(),
      withSuggestions: true,
    );
    expect({for (final g in groups) g.diveId}, {'d1', 'd2'});
  });

  test('with the feature off, tags only', () async {
    final groups = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: false,
    );
    expect(groups.single.suggested, isEmpty);
    expect(groups.single.tagged, hasLength(1));
  });

  test('the log is the active diver\'s: another diver\'s dives are left out, '
      'site photos kept', () async {
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd3', at: DateTime(2024, 1, 12), diverId: 'other');
    await insertTestMedia(id: 'r1', diveId: 'd3');
    await insertTestMedia(id: 'site1', siteId: 's1');
    for (final id in ['r1', 'site1']) {
      await tags.addTag(
        mediaId: id,
        speciesId: 'sp_blue_tang',
        unconfirmed: true,
      );
    }

    final groups = await review.load(
      const LogReviewScope(),
      withSuggestions: true,
      diverId: 'me',
    );

    expect(
      {for (final g in groups) g.diveId ?? g.kind.name},
      {'d1', 'd2', 'sitePhotos'},
    );
  });

  test('with no pack installed, the chosen level names a run by the bars it '
      'kept (issue #4876)', () async {
    await insertTestMedia(id: 'p4', diveId: 'd1');
    await identifications.storeRun(
      run(mediaId: 'p4').copyWith(
        namingBars: () => const NamingBars(
          minCropSide: 64,
          minOpenScore: 0.1,
          suggestScore: 0.95,
          suggestScoreNoLocation: 0.95,
          levels: [
            MeasuredNamingLevel(
              level: NamingLevel.eager,
              target: 0.65,
              suggestScore: 0.3,
              suggestScoreNoLocation: 0.3,
              precision: 0.7,
            ),
          ],
        ),
      ),
      insert: [
        identification('i-p4', mediaId: 'p4').copyWith(suggestable: false),
      ],
      deleteIds: const [],
    );

    final surer = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
      chosen: NamingLevel.surer,
    );
    final eager = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
      chosen: NamingLevel.eager,
    );

    int suggested(List<ReviewGroup> g) => g.isEmpty
        ? 0
        : g.single.suggested.fold(0, (n, r) => n + r.items.length);
    expect(suggested(eager), suggested(surer) + 1);
  });

  test('a looser naming level suggests a crop below the pack\'s bar', () async {
    await insertTestMedia(id: 'p3', diveId: 'd1');
    await identifications.storeRun(
      run(mediaId: 'p3'),
      insert: [
        identification('i-p3', mediaId: 'p3').copyWith(suggestable: false),
      ],
      deleteIds: const [],
    );
    const level = LevelInForce(
      level: NamingLevel.eager,
      packVersion: '2026.11.1',
      minCropSide: 64,
      minOpenScore: 0.1,
      suggestScore: 0.3,
      suggestScoreNoLocation: 0.3,
    );

    final stored = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
    );
    final loose = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
      level: level,
    );

    int suggested(List<ReviewGroup> g) =>
        g.single.suggested.fold(0, (n, r) => n + r.items.length);
    expect(suggested(loose), suggested(stored) + 1);
  });

  test('each media\'s run and rows are read in one snapshot (issues #4721, '
      '#4876), and no track paths', () async {
    final spy = _SpyIdentifications();
    final spied = SpeciesReviewRepository(
      tags: tags,
      identifications: spy,
      media: MediaRepository(),
      species: SpeciesRepository(),
      dives: DiveRepository(),
    );
    const level = LevelInForce(
      level: NamingLevel.eager,
      packVersion: '2026.11.1',
      minCropSide: 64,
      minOpenScore: 0.1,
      suggestScore: 0.3,
      suggestScoreNoLocation: 0.3,
    );

    await spied.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
      level: level,
    );
    // The snapshot, then the two reads it makes inside its transaction;
    // none of them decodes track paths.
    expect(spy.reads, ['snapshot', 'runs', 'rows']);

    // The pack's own level reads the snapshot too: the rows shown are
    // each run's own (issue #4876).
    spy.reads.clear();
    await spied.load(const DiveReviewScope('d1'), withSuggestions: true);
    expect(spy.reads, ['snapshot', 'runs', 'rows']);
  });

  test('a dive is headed by its own name before its site\'s', () async {
    final db = DatabaseService.instance.database;
    await insertTestSite('s1', 'Salt Pier');
    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(name: Value('Night dive'), siteId: Value('s1')),
    );
    await (db.update(db.dives)..where((t) => t.id.equals('d2'))).write(
      const DivesCompanion(siteId: Value('s1')),
    );

    final groups = await review.load(
      const LogReviewScope(),
      withSuggestions: true,
      diverId: 'me',
    );

    expect(
      {for (final g in groups) g.diveId: g.diveName},
      {'d1': 'Night dive', 'd2': 'Salt Pier'},
    );
  });
}
