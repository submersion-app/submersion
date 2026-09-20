import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_section_pairs.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';

void main() {
  test('Difficulty pairs with Rating and Hazards with Access', () {
    final difficulty = siteDetailSectionPairFor(SiteDetailSectionId.difficulty);
    expect(difficulty!.left, SiteDetailSectionId.difficulty);
    expect(difficulty.right, SiteDetailSectionId.rating);
    expect(
      identical(
        siteDetailSectionPairFor(SiteDetailSectionId.rating),
        difficulty,
      ),
      isTrue,
    );

    final hazards = siteDetailSectionPairFor(SiteDetailSectionId.access);
    expect(hazards!.left, SiteDetailSectionId.hazards);
    expect(hazards.right, SiteDetailSectionId.access);

    expect(siteDetailSectionPairFor(SiteDetailSectionId.notes), isNull);
  });

  test('no card belongs to two pairs', () {
    final seen = <SiteDetailSectionId>{};
    for (final pair in kSiteDetailSectionPairs) {
      expect(seen.add(pair.left), isTrue, reason: pair.left.name);
      expect(seen.add(pair.right), isTrue, reason: pair.right.name);
    }
  });

  test('each pair is adjacent and left first in the default order', () {
    const order = SiteDetailSectionId.values;
    for (final pair in kSiteDetailSectionPairs) {
      expect(order.indexOf(pair.right), order.indexOf(pair.left) + 1);
    }
  });

  test('partnerOf answers for both halves and nothing else', () {
    final pair = kSiteDetailSectionPairs.first;
    expect(pair.partnerOf(pair.left), pair.right);
    expect(pair.partnerOf(pair.right), pair.left);
    expect(pair.partnerOf(SiteDetailSectionId.notes), isNull);
  });

  test('pairs sit side by side from 700px', () {
    for (final pair in kSiteDetailSectionPairs) {
      expect(pair.minRowWidth, 700);
    }
  });
}
