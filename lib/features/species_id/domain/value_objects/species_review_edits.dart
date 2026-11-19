import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/features/species_id/domain/entities/species_review.dart';

/// What the diver decided about one media item of a review row.
enum ReviewDecision {
  /// The app's tag is right: it becomes the diver's own.
  confirm,

  /// The app's tag is wrong: it goes, with what it created.
  remove,

  /// The suggested species is right: tagged, as the diver's own.
  add,

  /// The suggestion is wrong: it does not come back for that item.
  dismiss;

  /// Whether the diver kept the species on the item (Confirm or Add)
  /// rather than dropping it (Remove or Dismiss).
  bool get keeps => this == confirm || this == add;
}

/// What Species to review holds until Save (issue #4727), by row and media
/// item. A media item belongs to one group, so the pair is unique across
/// the whole log.
@immutable
class SpeciesReviewEdits extends Equatable {
  const SpeciesReviewEdits._(this._decisions);

  static const none = SpeciesReviewEdits._({});

  final Map<String, ReviewDecision> _decisions;

  bool get isEmpty => _decisions.isEmpty;

  static String _key(String rowKey, String mediaId) => '$rowKey|$mediaId';

  ReviewDecision? decisionFor(String rowKey, String mediaId) =>
      _decisions[_key(rowKey, mediaId)];

  /// Every item of [row] has a decision.
  bool isRowSettled(ReviewRow row) =>
      row.items.every((i) => _decisions.containsKey(_key(row.key, i.media.id)));

  /// The decision keeping ([keep]) or dropping [item] means: confirm or
  /// remove an app tag, add or dismiss a suggestion.
  static ReviewDecision decisionOf(ReviewItem item, {required bool keep}) =>
      item.isTagged
      ? (keep ? ReviewDecision.confirm : ReviewDecision.remove)
      : (keep ? ReviewDecision.add : ReviewDecision.dismiss);

  /// The row's button: every item of [row] not yet decided is kept or
  /// dropped. A species tagged on some items and suggested on others is
  /// confirmed and added, or removed and dismissed, together.
  SpeciesReviewEdits decideRow(ReviewRow row, {required bool keep}) =>
      SpeciesReviewEdits._({
        ..._decisions,
        for (final i in row.items)
          if (!_decisions.containsKey(_key(row.key, i.media.id)))
            _key(row.key, i.media.id): decisionOf(i, keep: keep),
      });

  /// One item's button, in the expanded row.
  SpeciesReviewEdits decideItem(
    ReviewRow row,
    ReviewItem item, {
    required bool keep,
  }) => SpeciesReviewEdits._({
    ..._decisions,
    _key(row.key, item.media.id): decisionOf(item, keep: keep),
  });

  SpeciesReviewEdits undoRow(ReviewRow row) => SpeciesReviewEdits._({
    for (final e in _decisions.entries)
      if (!row.items.any((i) => e.key == _key(row.key, i.media.id)))
        e.key: e.value,
  });

  /// These decisions less those on a row and media item [groups] no longer
  /// list: a reload may have settled a row elsewhere, or moved a photo to
  /// another species' row, where it is decided afresh.
  SpeciesReviewEdits prunedTo(List<ReviewGroup> groups) {
    final listed = {
      for (final group in groups)
        for (final row in [...group.tagged, ...group.suggested])
          for (final item in row.items) _key(row.key, item.media.id),
    };
    if (_decisions.keys.every(listed.contains)) return this;
    return SpeciesReviewEdits._({
      for (final e in _decisions.entries)
        if (listed.contains(e.key)) e.key: e.value,
    });
  }

  SpeciesReviewEdits undoItem(ReviewRow row, ReviewItem item) =>
      SpeciesReviewEdits._(
        {..._decisions}..remove(_key(row.key, item.media.id)),
      );

  @override
  List<Object?> get props => [_decisions];
}
