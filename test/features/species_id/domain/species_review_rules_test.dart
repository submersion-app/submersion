import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/species_review_rules.dart';

import '../data/identification_fixtures.dart';

/// What Species to review lists: one row per species per dive, the app's
/// unconfirmed tags first, then suggestions (issue #4727).
void main() {
  MediaItem media(String id, {String? diveId, String? siteId}) => MediaItem(
    id: id,
    diveId: diveId,
    siteId: siteId,
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  ReviewMedia onDive(String id, String diveId, DateTime when) => ReviewMedia(
    item: media(id, diveId: diveId),
    diveNumber: 42,
    diveTime: when,
  );
  MediaSpeciesTag appTag(String mediaId, String speciesId) => MediaSpeciesTag(
    id: 't-$mediaId-$speciesId',
    mediaId: mediaId,
    speciesId: speciesId,
    createdAt: DateTime.utc(2026),
    unconfirmed: true,
  );
  final suggestion = groupSuggestions([identification('i1')], const []).single;
  const parrotfish = Species(
    id: 'sp_queen_parrotfish',
    commonName: 'Queen Parrotfish',
    scientificName: 'Scarus vetula',
    category: SpeciesCategory.fish,
    isBuiltIn: true,
  );
  final may = DateTime.utc(2026, 5, 3);
  final june = DateTime.utc(2026, 6, 1);

  test('tagged on two photos and suggested on three is one tagged row', () {
    final groups = buildReviewGroups(
      media: [
        for (final id in ['a', 'b', 'c', 'd', 'e']) onDive(id, 'd1', may),
      ],
      unconfirmedByMedia: {
        'a': [appTag('a', parrotfish.id)],
        'b': [appTag('b', parrotfish.id)],
      },
      suggestionsByMedia: {
        for (final id in ['c', 'd', 'e']) id: [suggestion],
      },
      speciesById: {parrotfish.id: parrotfish},
    );

    final dive = groups.single;
    expect(dive.suggested, isEmpty);
    final row = dive.tagged.single;
    expect((row.taggedCount, row.suggestedCount), (2, 3));
    expect(row.speciesId, parrotfish.id);
    expect(reviewCount(groups), 1);
  });

  test('a species only suggested is a suggested row', () {
    final groups = buildReviewGroups(
      media: [onDive('c', 'd1', may)],
      unconfirmedByMedia: const {},
      suggestionsByMedia: {
        'c': [suggestion],
      },
      speciesById: const {},
    );
    expect(groups.single.tagged, isEmpty);
    expect(groups.single.suggested.single.candidate, suggestion.top.candidate);
  });

  test('dives newest first, then site photos, then other photos', () {
    final groups = buildReviewGroups(
      media: [
        onDive('a', 'old', may),
        ReviewMedia(
          item: media('s', siteId: 'site1'),
          siteName: 'Punta Sur',
        ),
        ReviewMedia(item: media('o')),
        onDive('b', 'new', june),
      ],
      unconfirmedByMedia: {
        for (final id in ['a', 's', 'o', 'b']) id: [appTag(id, parrotfish.id)],
      },
      suggestionsByMedia: const {},
      speciesById: {parrotfish.id: parrotfish},
    );
    expect(
      [for (final g in groups) g.diveId ?? g.kind.name],
      ['new', 'old', 'sitePhotos', 'otherPhotos'],
    );
    expect(reviewCount(groups), 4);
  });

  test('media with nothing to review makes no group', () {
    final groups = buildReviewGroups(
      media: [onDive('a', 'd1', may)],
      unconfirmedByMedia: const {},
      suggestionsByMedia: const {},
      speciesById: const {},
    );
    expect(groups, isEmpty);
  });

  test('review entities copy with each field', () {
    final m = onDive('a', 'd1', may);
    expect(m.copyWith(siteName: () => 'Punta Sur').siteName, 'Punta Sur');
    expect(m.copyWith(diveNumber: () => null).diveNumber, isNull);
    final row = ReviewRow(key: 's:x', items: const []);
    expect(row.copyWith(key: 's:y').key, 's:y');
    final group = ReviewGroup(
      kind: ReviewGroupKind.dive,
      tagged: const [],
      suggested: const [],
      diveId: 'd1',
    );
    expect(group.copyWith(diveId: () => null).diveId, isNull);
    expect(group.copyWith(tagged: [row]).tagged, [row]);
  });
}
