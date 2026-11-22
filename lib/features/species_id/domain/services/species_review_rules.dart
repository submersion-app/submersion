/// What Species to review lists (issue #4727). Pure, so every platform
/// groups alike, including where marine life identification does not run
/// and only the app's synced tags are there to review.
library;

import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

/// What a device holds behind one of the app's tags: the accepted
/// identification whose crop shows it, and the tagged species' own score and
/// GBIF key in it, null when that identification no longer lists the species.
typedef TagEvidence = ({double? score, String identificationId, int? gbifKey});

/// One row per species per dive: a species the app tagged on some media and
/// only suggested on others is one tagged row. Groups go dives newest first,
/// then photos with a site and no dive, then the rest. Media with nothing
/// to review make no group.
List<ReviewGroup> buildReviewGroups({
  required List<ReviewMedia> media,
  required Map<String, List<MediaSpeciesTag>> unconfirmedByMedia,
  required Map<String, List<SpeciesSuggestion>> suggestionsByMedia,
  required Map<String, Species> speciesById,
  Map<String, TagEvidence> tagEvidence = const {},
}) {
  final byGroup = <String, List<ReviewMedia>>{};
  for (final m in media) {
    final item = m.item;
    final key =
        item.diveId ??
        (item.siteId != null
            ? ReviewGroupKind.sitePhotos.name
            : ReviewGroupKind.otherPhotos.name);
    byGroup.putIfAbsent(key, () => []).add(m);
  }
  final groups = <ReviewGroup>[];
  for (final MapEntry(key: key, value: members) in byGroup.entries) {
    final rows = <String, List<ReviewItem>>{};
    final speciesOf = <String, Species>{};
    final candidateOf = <String, ReviewItem>{};
    for (final m in members) {
      for (final tag in unconfirmedByMedia[m.item.id] ?? const []) {
        final rowKey = 's:${tag.speciesId}';
        final species = speciesById[tag.speciesId];
        if (species != null) speciesOf[rowKey] = species;
        // The identification the tag came from, when this device holds it.
        final evidence = tagEvidence[tag.id];
        rows
            .putIfAbsent(rowKey, () => [])
            .add(
              ReviewItem(
                media: m.item,
                tag: tag,
                score: evidence?.score,
                cropIdentificationId: evidence?.identificationId,
                tagGbifKey: evidence?.gbifKey,
              ),
            );
      }
    }
    for (final m in members) {
      for (final s in suggestionsByMedia[m.item.id] ?? const []) {
        final tagged = rows.keys.where((k) => k.startsWith('s:')).firstWhere((
          k,
        ) {
          final id = k.substring(2);
          return candidateMatches(
            s.top.candidate,
            TaggedSpecies(
              speciesId: id,
              scientificName: speciesById[id]?.scientificName,
            ),
          );
        }, orElse: () => 'g:${s.top.candidate.gbifKey}');
        final item = ReviewItem(
          media: m.item,
          suggestion: s,
          score: s.score,
          cropIdentificationId: s.cropIdentificationId,
        );
        rows.putIfAbsent(tagged, () => []).add(item);
        candidateOf.putIfAbsent(tagged, () => item);
      }
    }
    if (rows.isEmpty) continue;
    final built = [
      for (final MapEntry(key: rowKey, value: items) in rows.entries)
        ReviewRow(
          key: rowKey,
          items: items,
          species: speciesOf[rowKey],
          candidate: rowKey.startsWith('g:')
              ? candidateOf[rowKey]!.suggestion!.top.candidate
              : null,
        ),
    ];
    final first = members.first;
    groups.add(
      ReviewGroup(
        kind: key == ReviewGroupKind.sitePhotos.name
            ? ReviewGroupKind.sitePhotos
            : key == ReviewGroupKind.otherPhotos.name
            ? ReviewGroupKind.otherPhotos
            : ReviewGroupKind.dive,
        diveId: first.item.diveId,
        diveNumber: first.diveNumber,
        diveTime: first.diveTime,
        diveName: first.diveName,
        tagged: [
          for (final r in built)
            if (r.isTagged) r,
        ]..sort((a, b) => _name(a).compareTo(_name(b))),
        suggested: [
          for (final r in built)
            if (!r.isTagged) r,
        ]..sort((a, b) => (b.bestScore ?? 0).compareTo(a.bestScore ?? 0)),
      ),
    );
  }
  int rank(ReviewGroup g) => g.kind.index;
  groups.sort((a, b) {
    final byKind = rank(a).compareTo(rank(b));
    if (byKind != 0) return byKind;
    final at = a.diveTime;
    final bt = b.diveTime;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  });
  return groups;
}

String _name(ReviewRow row) =>
    (row.species?.commonName ?? row.candidate?.commonName ?? '').toLowerCase();

/// How many species there are to review across [groups].
int reviewCount(List<ReviewGroup> groups) =>
    groups.fold(0, (sum, g) => sum + g.tagged.length + g.suggested.length);
