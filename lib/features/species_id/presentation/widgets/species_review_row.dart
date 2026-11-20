import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/recorded_nearby_line.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The name a review row shows: the species the app tagged, else the app's
/// name for the suggestion.
String reviewRowName(AppLocalizations l10n, ReviewRow row) {
  final species = row.species;
  if (species != null) {
    return localizedSpeciesName(l10n, species.id, species.commonName);
  }
  return candidateDisplayName(l10n, row.candidate!);
}

/// One species on one dive, with its decision buttons; expands to one line
/// per photo or video (issue #4727).
class SpeciesReviewRowTile extends StatelessWidget {
  const SpeciesReviewRowTile({
    super.key,
    required this.row,
    required this.edits,
    required this.expanded,
    required this.onToggle,
    required this.onRow,
    required this.onItem,
    required this.onOpen,
  });

  final ReviewRow row;
  final SpeciesReviewEdits edits;
  final bool expanded;
  final VoidCallback onToggle;

  /// Keep or drop the whole row; null undoes it.
  final void Function(bool? keep) onRow;

  /// Keep or drop one item; null undoes it.
  final void Function(ReviewItem item, bool? keep) onItem;
  final void Function(ReviewItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = reviewRowName(l10n, row);
    final settled = edits.isRowSettled(row);
    final best = row.best;
    final score = row.bestScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: ValueKey('species_review_row_${row.key}_${best.media.id}'),
          onTap: onToggle,
          leading: _ReviewThumb(
            item: best,
            size: 56,
            label: name,
            onTap: () => onOpen(best),
          ),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [
                  _counts(l10n, row),
                  if (row.isTagged && row.suggestedCount > 0)
                    l10n.speciesReview_mixed(
                      row.taggedCount,
                      row.suggestedCount,
                    ),
                  if (score != null) _percent(context, score),
                ].join(' '),
              ),
              // Once per row: its photos' lines below would only repeat it.
              RecordedNearbyLine(
                request: _nearbyRequest(best),
                gbifKeys: row.gbifKeys,
                catalogId: row.species?.id ?? row.candidate?.catalogId,
              ),
            ],
          ),
          trailing: settled
              ? _Settled(
                  label: _rowLabel(l10n),
                  onUndo: () => onRow(null),
                  undoKey: ValueKey('species_review_undo_${row.key}'),
                )
              : _Buttons(
                  keepLabel: row.isTagged
                      ? l10n.speciesReview_confirm
                      : l10n.speciesReview_add,
                  keepKey: ValueKey('species_review_keep_${row.key}'),
                  dropKey: ValueKey('species_review_drop_${row.key}'),
                  dropLabel: row.isTagged ? l10n.speciesReview_remove : null,
                  dropTooltip: l10n.speciesReview_dismiss(name),
                  onKeep: () => onRow(true),
                  onDrop: () => onRow(false),
                ),
        ),
        if (expanded)
          for (final item in row.items) _itemLine(context, item),
      ],
    );
  }

  Widget _itemLine(BuildContext context, ReviewItem item) {
    final l10n = context.l10n;
    final decision = edits.decisionFor(row.key, item.media.id);
    final score = item.score;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 32),
      child: ListTile(
        dense: true,
        leading: _ReviewThumb(
          item: item,
          size: 40,
          label: reviewRowName(l10n, row),
          onTap: () => onOpen(item),
        ),
        title: Text(
          item.isTagged
              ? l10n.speciesReview_itemTagged
              : l10n.speciesReview_itemSuggested,
        ),
        subtitle: score == null ? null : Text(_percent(context, score)),
        trailing: decision != null
            ? _Settled(
                label: _decisionLabel(l10n, decision),
                onUndo: () => onItem(item, null),
              )
            : _Buttons(
                keepLabel: item.isTagged
                    ? l10n.speciesReview_confirm
                    : l10n.speciesReview_add,
                dropLabel: item.isTagged ? l10n.speciesReview_remove : null,
                dropTooltip: l10n.speciesReview_dismiss(
                  reviewRowName(l10n, row),
                ),
                keepKey: ValueKey(
                  'species_review_item_keep_${row.key}_${item.media.id}',
                ),
                dropKey: ValueKey(
                  'species_review_item_drop_${row.key}_${item.media.id}',
                ),
                onKeep: () => onItem(item, true),
                onDrop: () => onItem(item, false),
              ),
      ),
    );
  }

  /// The row's one decision, or Decided when its items differ.
  String _rowLabel(AppLocalizations l10n) {
    final decisions = {
      for (final i in row.items) edits.decisionFor(row.key, i.media.id),
    };
    return decisions.length == 1
        ? _decisionLabel(l10n, decisions.single!)
        : l10n.speciesReview_decided;
  }

  /// Whose nearby list a row reads: its dive's, so one list serves every
  /// row of a dive; photos in no dive read the shown photo's own position.
  static NearbyListRequest _nearbyRequest(ReviewItem best) =>
      best.media.diveId != null
      ? (diveId: best.media.diveId, photo: null)
      : nearbyRequestForMedia(best.media);

  /// A score as the locale writes a percentage, as the species sheet does.
  static String _percent(BuildContext context, double score) =>
      NumberFormat.percentPattern(
        Localizations.localeOf(context).toString(),
      ).format(score);

  static String _counts(AppLocalizations l10n, ReviewRow row) {
    final videos = row.items
        .where((i) => i.media.mediaType == MediaType.video)
        .length;
    final photos = row.items.length - videos;
    if (videos == 0) return l10n.speciesReview_onPhotos(photos);
    if (photos == 0) return l10n.speciesReview_onVideos(videos);
    return l10n.speciesReview_onPhotosAndVideos(row.items.length);
  }

  static String _decisionLabel(AppLocalizations l10n, ReviewDecision d) =>
      switch (d) {
        ReviewDecision.confirm => l10n.speciesReview_confirmed,
        ReviewDecision.remove => l10n.speciesReview_removed,
        ReviewDecision.add => l10n.speciesReview_added,
        ReviewDecision.dismiss => l10n.speciesReview_dismissed,
      };
}

/// A crop when this device holds one, else the photo or video's thumbnail.
class _ReviewThumb extends StatelessWidget {
  const _ReviewThumb({
    required this.item,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final ReviewItem item;
  final double size;

  /// The species, read out for the button that opens the photo.
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crop = item.cropIdentificationId;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: size,
            child: crop != null
                ? IdentificationCrop(
                    mediaId: item.media.id,
                    identificationId: crop,
                  )
                : MediaItemView(
                    item: item.media,
                    thumbnail: true,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.keepLabel,
    required this.dropLabel,
    required this.dropTooltip,
    required this.keepKey,
    required this.dropKey,
    required this.onKeep,
    required this.onDrop,
  });

  final String keepLabel;

  /// Shown as a text button (Remove); null shows a dismiss icon instead.
  final String? dropLabel;
  final String dropTooltip;
  final Key keepKey;
  final Key dropKey;
  final VoidCallback onKeep;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final drop = dropLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(key: keepKey, onPressed: onKeep, child: Text(keepLabel)),
        if (drop != null)
          TextButton(key: dropKey, onPressed: onDrop, child: Text(drop))
        else
          IconButton(
            key: dropKey,
            tooltip: dropTooltip,
            icon: const Icon(Icons.close),
            onPressed: onDrop,
          ),
      ],
    );
  }
}

class _Settled extends StatelessWidget {
  const _Settled({required this.label, required this.onUndo, this.undoKey});

  final String label;
  final VoidCallback onUndo;
  final Key? undoKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      TextButton(
        key: undoKey,
        onPressed: onUndo,
        child: Text(context.l10n.speciesReview_undo),
      ),
    ],
  );
}
