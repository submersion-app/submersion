import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';

import '../data/identification_fixtures.dart';

/// What the diver decides on Species to review, held until Save (issue
/// #4727).
void main() {
  MediaItem media(String id) => MediaItem(
    id: id,
    diveId: 'd1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final suggestion = groupSuggestions([identification('i1')], const []).single;
  final tagged = ReviewItem(
    media: media('a'),
    tag: MediaSpeciesTag(
      id: 't1',
      mediaId: 'a',
      speciesId: 'sp1',
      createdAt: DateTime.utc(2026),
      unconfirmed: true,
    ),
  );
  final suggested = ReviewItem(media: media('b'), suggestion: suggestion);
  final row = ReviewRow(key: 's:sp1', items: [tagged, suggested]);

  test('Confirm on a mixed row confirms the tags and adds the suggestions', () {
    final edits = SpeciesReviewEdits.none.decideRow(row, keep: true);
    expect(edits.decisionFor(row.key, 'a'), ReviewDecision.confirm);
    expect(edits.decisionFor(row.key, 'b'), ReviewDecision.add);
    expect(edits.isRowSettled(row), isTrue);
  });

  test('Remove on a mixed row removes the tags and dismisses the '
      'suggestions', () {
    final edits = SpeciesReviewEdits.none.decideRow(row, keep: false);
    expect(edits.decisionFor(row.key, 'a'), ReviewDecision.remove);
    expect(edits.decisionFor(row.key, 'b'), ReviewDecision.dismiss);
  });

  test('a row\'s button leaves an item already decided as it is', () {
    final edits = SpeciesReviewEdits.none
        .decideItem(row, tagged, keep: false)
        .decideRow(row, keep: true);
    expect(edits.decisionFor(row.key, 'a'), ReviewDecision.remove);
    expect(edits.decisionFor(row.key, 'b'), ReviewDecision.add);
  });

  test('undoing every decision leaves nothing to save', () {
    final edits = SpeciesReviewEdits.none
        .decideRow(row, keep: true)
        .undoRow(row);
    expect(edits.isEmpty, isTrue);
    expect(
      SpeciesReviewEdits.none
          .decideItem(row, suggested, keep: true)
          .undoItem(row, suggested)
          .isEmpty,
      isTrue,
    );
  });

  test('prunedTo drops decisions on a photo no longer in that row', () {
    final edits = SpeciesReviewEdits.none.decideRow(row, keep: false);
    // A reload moved b to another species' row; a stays where it was.
    final pruned = edits.prunedTo([
      ReviewGroup(
        kind: ReviewGroupKind.dive,
        tagged: [
          ReviewRow(key: 's:sp1', items: [tagged]),
          ReviewRow(key: 's:sp2', items: [suggested]),
        ],
        suggested: const [],
      ),
    ]);

    expect(pruned.decisionFor('s:sp1', 'a'), ReviewDecision.remove);
    expect(pruned.decisionFor('s:sp1', 'b'), isNull);
  });

  test('prunedTo keeps every decision still listed', () {
    final edits = SpeciesReviewEdits.none.decideRow(row, keep: true);

    expect(
      edits.prunedTo([
        ReviewGroup(
          kind: ReviewGroupKind.dive,
          tagged: [row],
          suggested: const [],
        ),
      ]),
      edits,
    );
  });
}
