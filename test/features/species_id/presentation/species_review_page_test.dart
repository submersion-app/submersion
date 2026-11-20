import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/data/services/species_review_saver.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';
import 'package:submersion/features/species_id/presentation/pages/species_review_page.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

import '../../media/presentation/support/media_widget_harness.dart';
import '../data/identification_fixtures.dart';

/// Records what Save was given, writing nothing.
class _Saver implements SpeciesReviewSaver {
  final saved = <SpeciesReviewEdits>[];
  Object? failure;

  @override
  Future<void> save(SpeciesReviewEdits edits, List<ReviewGroup> groups) async {
    if (failure != null) throw failure!;
    saved.add(edits);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Species to review: decisions held until Save (issue #4727).
void main() {
  const scope = DiveReviewScope('d1');
  late _Saver saver;

  final tagged = ReviewItem(
    media: testMediaItem(id: 'a', diveId: 'd1'),
    tag: MediaSpeciesTag(
      id: 't1',
      mediaId: 'a',
      speciesId: 'sp1',
      createdAt: DateTime.utc(2026),
      unconfirmed: true,
    ),
  );
  final tagRow = ReviewRow(
    key: 's:sp1',
    species: const Species(
      id: 'sp1',
      commonName: 'Rock Beauty',
      category: SpeciesCategory.fish,
    ),
    items: [tagged],
  );
  final suggestion = groupSuggestions([identification('i1')], const []).single;
  final suggestedRow = ReviewRow(
    key: 'g:1',
    candidate: suggestion.top.candidate,
    items: [
      ReviewItem(
        media: testMediaItem(id: 'b', diveId: 'd1'),
        suggestion: suggestion,
        score: 0.71,
      ),
    ],
  );

  /// The "Recorded nearby" list each row is asked about, by request.
  late List<NearbyListRequest> nearbyAsked;

  /// Pumps the page; the "Recorded nearby" list is [nearby], so no test
  /// here reaches GBIF.
  Future<void> pump(
    WidgetTester tester, {
    required List<ReviewRow> taggedRows,
    List<ReviewRow> suggestedRows = const [],
    NearbySpecies? nearby,
    Completer<NearbySpecies?>? pending,
  }) async {
    saver = _Saver();
    nearbyAsked = [];
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          speciesReviewProvider(scope).overrideWith(
            (ref) async => [
              // The repository makes no group for media with nothing.
              if (taggedRows.isNotEmpty || suggestedRows.isNotEmpty)
                ReviewGroup(
                  kind: ReviewGroupKind.dive,
                  diveId: 'd1',
                  diveNumber: 42,
                  diveName: 'Punta Sur',
                  tagged: taggedRows,
                  suggested: suggestedRows,
                ),
            ],
          ),
          speciesReviewSaverProvider.overrideWithValue(saver),
          recordedNearbyListProvider.overrideWith((ref, request) {
            nearbyAsked.add(request);
            return pending?.future ?? Future.value(nearby);
          }),
        ],
        home: const SpeciesReviewPage(scope: scope),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder save() => find.byKey(const ValueKey('species_review_save'));

  group('Recorded nearby (issue #4668)', () {
    Finder markerIn(String rowKey) => find.descendant(
      of: find.byKey(ValueKey(rowKey)),
      matching: find.text('Recorded nearby'),
    );
    const taggedRowKey = 'species_review_row_s:sp1_a';
    const suggestedRowKey = 'species_review_row_g:1_b';
    // The suggested row's candidate, by its GBIF key alone.
    const keyOnly = NearbySpecies(speciesKeys: {2393681});

    testWidgets('a suggested row recorded nearby says so', (tester) async {
      await pump(
        tester,
        taggedRows: [tagRow],
        suggestedRows: [suggestedRow],
        nearby: keyOnly,
      );
      expect(markerIn(suggestedRowKey), findsOneWidget);
      expect(markerIn(taggedRowKey), findsNothing);
      // The dive's list: a review row passes no photo position.
      expect(nearbyAsked.toSet(), {(diveId: 'd1', photo: null)});
    });

    testWidgets('a tagged row of a catalogue species on the list says so', (
      tester,
    ) async {
      await pump(
        tester,
        taggedRows: [tagRow],
        nearby: const NearbySpecies(
          matched: [MatchedNearbySpecies(speciesId: 'sp1', occurrenceCount: 3)],
        ),
      );
      expect(markerIn(taggedRowKey), findsOneWidget);
    });

    testWidgets('an app tag of a species outside the catalogue says so, by '
        'the key it was tagged from', (tester) async {
      final ownRow = ReviewRow(
        key: 's:own-9',
        species: const Species(
          id: 'own-9',
          commonName: 'Spotted Drum',
          category: SpeciesCategory.fish,
        ),
        items: [
          ReviewItem(
            media: testMediaItem(id: 'a', diveId: 'd1'),
            tag: MediaSpeciesTag(
              id: 't9',
              mediaId: 'a',
              speciesId: 'own-9',
              createdAt: DateTime.utc(2026),
              unconfirmed: true,
            ),
            tagGbifKey: 2401398,
          ),
        ],
      );
      await pump(
        tester,
        taggedRows: [ownRow],
        nearby: const NearbySpecies(speciesKeys: {2401398}),
      );
      expect(markerIn('species_review_row_s:own-9_a'), findsOneWidget);
    });

    testWidgets('a row of photos in no dive reads its photo\'s own position', (
      tester,
    ) async {
      saver = _Saver();
      nearbyAsked = [];
      final unfiled = ReviewRow(
        key: 'g:1',
        candidate: suggestedRow.candidate,
        items: [
          ReviewItem(
            media: testMediaItem(
              id: 'e',
            ).copyWith(latitude: 12.2, longitude: -68.3),
            suggestion: suggestion,
            score: 0.71,
          ),
        ],
      );
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            speciesReviewProvider(scope).overrideWith(
              (ref) async => [
                ReviewGroup(
                  kind: ReviewGroupKind.otherPhotos,
                  tagged: const [],
                  suggested: [unfiled],
                ),
              ],
            ),
            speciesReviewSaverProvider.overrideWithValue(saver),
            recordedNearbyListProvider.overrideWith((ref, request) {
              nearbyAsked.add(request);
              return Future.value(keyOnly);
            }),
          ],
          home: const SpeciesReviewPage(scope: scope),
        ),
      );
      await tester.pumpAndSettle();

      expect(nearbyAsked.toSet(), {
        (diveId: null, photo: const GeoPoint(12.2, -68.3)),
      });
      expect(markerIn('species_review_row_g:1_e'), findsOneWidget);
    });

    testWidgets('a row of the app\'s tags says so by its tag\'s key, though '
        'a suggestion with another key is grouped under it', (tester) async {
      // The suggestion matched the tagged species by name, under a synonym's
      // key; the tag was made from the key the nearby list holds.
      final ownRow = ReviewRow(
        key: 's:own-9',
        species: const Species(
          id: 'own-9',
          commonName: 'Spotted Drum',
          category: SpeciesCategory.fish,
        ),
        items: [
          ReviewItem(
            media: testMediaItem(id: 'a', diveId: 'd1'),
            tag: MediaSpeciesTag(
              id: 't9',
              mediaId: 'a',
              speciesId: 'own-9',
              createdAt: DateTime.utc(2026),
              unconfirmed: true,
            ),
            tagGbifKey: 2401398,
          ),
          ReviewItem(
            media: testMediaItem(id: 'b', diveId: 'd1'),
            suggestion: suggestion,
            score: 0.71,
          ),
        ],
      );
      await pump(
        tester,
        taggedRows: [ownRow],
        nearby: const NearbySpecies(speciesKeys: {2401398}),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('species_review_row_s:own-9_b')),
          matching: find.text('Recorded nearby'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the marker is read with the row', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        taggedRows: [tagRow],
        suggestedRows: [suggestedRow],
        nearby: keyOnly,
      );
      // One label holds the species, its counts and the marker: a screen
      // reader says them together, not as a stray line of its own.
      expect(
        find.bySemanticsLabel(
          RegExp(r'Queen Parrotfish[\s\S]*on 1 photo[\s\S]*Recorded nearby'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Recorded nearby'), findsNothing);
      semantics.dispose();
    });

    testWidgets('the marker adds no colour to the row\'s secondary line', (
      tester,
    ) async {
      await pump(
        tester,
        taggedRows: const [],
        suggestedRows: [suggestedRow],
        nearby: keyOnly,
      );
      Color? colourOf(Finder text) =>
          tester.renderObject<RenderParagraph>(text).text.style?.color;
      expect(
        colourOf(find.text('Recorded nearby')),
        colourOf(find.textContaining('on 1 photo')),
      );
    });

    testWidgets('while the list loads, no row shows the marker', (
      tester,
    ) async {
      await pump(
        tester,
        taggedRows: [tagRow],
        suggestedRows: [suggestedRow],
        pending: Completer<NearbySpecies?>(),
      );
      expect(find.text('Rock Beauty'), findsOneWidget);
      expect(find.text('Recorded nearby'), findsNothing);
    });

    testWidgets('with no list, no row shows the marker', (tester) async {
      await pump(tester, taggedRows: [tagRow], suggestedRows: [suggestedRow]);
      expect(find.text('Rock Beauty'), findsOneWidget);
      expect(find.text('Recorded nearby'), findsNothing);
    });

    testWidgets('an expanded row says it once, not on each photo', (
      tester,
    ) async {
      final twoPhotos = ReviewRow(
        key: 'g:1',
        candidate: suggestedRow.candidate,
        items: [
          ...suggestedRow.items,
          ReviewItem(
            media: testMediaItem(id: 'c', diveId: 'd1'),
            suggestion: suggestion,
            score: 0.64,
          ),
        ],
      );
      await pump(
        tester,
        taggedRows: const [],
        suggestedRows: [twoPhotos],
        nearby: keyOnly,
      );
      await tester.tap(find.text('Queen Parrotfish'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded nearby'), findsOneWidget);
    });
  });

  testWidgets('both sections, with the dive in the title', (tester) async {
    await pump(tester, taggedRows: [tagRow], suggestedRows: [suggestedRow]);

    expect(find.text('Dive 42, Punta Sur'), findsOneWidget);
    expect(find.text('Tagged by the app, not yet confirmed'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Rock Beauty'), findsOneWidget);
    expect(find.textContaining('on 1 photo'), findsWidgets);
  });

  testWidgets('Confirm is held until Save', (tester) async {
    await pump(tester, taggedRows: [tagRow]);
    expect(tester.widget<AppBarTextAction>(save()).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('species_review_keep_s:sp1')));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsOneWidget);
    expect(saver.saved, isEmpty);

    await tester.tap(save());
    await tester.pumpAndSettle();
    expect(
      saver.saved.single.decisionFor('s:sp1', 'a'),
      ReviewDecision.confirm,
    );
  });

  testWidgets('Cancel with a decision asks first', (tester) async {
    await pump(tester, taggedRows: [tagRow]);
    await tester.tap(find.byKey(const ValueKey('species_review_drop_s:sp1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('species_review_cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('tags only, with no Suggested section, where identification '
      'does not run', (tester) async {
    await pump(tester, taggedRows: [tagRow]);
    expect(find.text('Suggested'), findsNothing);
    expect(find.text('Rock Beauty'), findsOneWidget);
  });

  testWidgets('nothing to review', (tester) async {
    await pump(tester, taggedRows: const []);
    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('a row decided differently per photo reads Decided', (
    tester,
  ) async {
    final mixed = ReviewRow(
      key: 's:sp1',
      species: tagRow.species,
      items: [tagged, ...suggestedRow.items],
    );
    await pump(tester, taggedRows: [mixed]);
    await tester.tap(find.text('Rock Beauty'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('species_review_item_keep_s:sp1_a')),
    );
    await tester.tap(
      find.byKey(const ValueKey('species_review_item_drop_s:sp1_b')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Decided'), findsOneWidget);
  });

  testWidgets('a save that fails says so and keeps the decisions', (
    tester,
  ) async {
    await pump(tester, taggedRows: [tagRow]);
    saver.failure = StateError('database closed');
    await tester.tap(find.byKey(const ValueKey('species_review_keep_s:sp1')));
    await tester.pumpAndSettle();
    await tester.tap(save());
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('a decision whose row a reload replaced is dropped: nothing '
      'is left to save', (tester) async {
    saver = _Saver();
    var rows = (tagged: const <ReviewRow>[], suggested: [suggestedRow]);
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          speciesReviewProvider(scope).overrideWith(
            (ref) async => [
              ReviewGroup(
                kind: ReviewGroupKind.dive,
                diveId: 'd1',
                tagged: rows.tagged,
                suggested: rows.suggested,
              ),
            ],
          ),
          speciesReviewSaverProvider.overrideWithValue(saver),
          // No list: nothing here reaches GBIF or a logbook.
          recordedNearbyListProvider.overrideWith((ref, request) async => null),
        ],
        home: const SpeciesReviewPage(scope: scope),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('species_review_drop_g:1')));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBarTextAction>(save()).onPressed, isNotNull);

    // A run applies the suggested species to photo b meanwhile: b is now
    // the app's tag, in the species' own row, to decide afresh.
    rows = (
      tagged: [
        ReviewRow(
          key: 's:sp1',
          species: tagRow.species,
          items: [
            ReviewItem(
              media: suggestedRow.items.single.media,
              tag: MediaSpeciesTag(
                id: 't2',
                mediaId: 'b',
                speciesId: 'sp1',
                createdAt: DateTime.utc(2026),
                unconfirmed: true,
              ),
            ),
          ],
        ),
      ],
      suggested: const <ReviewRow>[],
    );
    ProviderScope.containerOf(
      tester.element(find.byType(SpeciesReviewPage)),
    ).invalidate(speciesReviewProvider(scope));
    await tester.pumpAndSettle();

    expect(tester.widget<AppBarTextAction>(save()).onPressed, isNull);
  });

  testWidgets('a dive with no number and no name is headed as the dive '
      'pages head it', (tester) async {
    saver = _Saver();
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          speciesReviewProvider(scope).overrideWith(
            (ref) async => [
              ReviewGroup(
                kind: ReviewGroupKind.dive,
                diveId: 'd1',
                tagged: [tagRow],
                suggested: const [],
              ),
            ],
          ),
          speciesReviewSaverProvider.overrideWithValue(saver),
          // No list: nothing here reaches GBIF or a logbook.
          recordedNearbyListProvider.overrideWith((ref, request) async => null),
        ],
        home: const SpeciesReviewPage(scope: scope),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown Site'), findsOneWidget);
  });

  testWidgets('a review that cannot be read says so, not that there is '
      'nothing', (tester) async {
    saver = _Saver();
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          speciesReviewProvider(
            scope,
          ).overrideWith((ref) async => throw StateError('no logbook')),
          speciesReviewSaverProvider.overrideWithValue(saver),
          // No list: nothing here reaches GBIF or a logbook.
          recordedNearbyListProvider.overrideWith((ref, request) async => null),
        ],
        home: const SpeciesReviewPage(scope: scope),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Nothing to review'), findsNothing);
  });
}
