import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/species_review_saver.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';
import 'package:submersion/features/species_id/presentation/pages/species_review_page.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    required List<ReviewRow> taggedRows,
    List<ReviewRow> suggestedRows = const [],
  }) async {
    saver = _Saver();
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
                  siteName: 'Punta Sur',
                  tagged: taggedRows,
                  suggested: suggestedRows,
                ),
            ],
          ),
          speciesReviewSaverProvider.overrideWithValue(saver),
        ],
        home: const SpeciesReviewPage(scope: scope),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder save() => find.byKey(const ValueKey('species_review_save'));

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
}
