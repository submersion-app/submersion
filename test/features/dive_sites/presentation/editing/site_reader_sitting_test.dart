import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';

/// Which of the site page's cards a library reader's sitting edits as the
/// reader's own, suggests to the owner, or leaves as the library's (issue
/// #4527, phase 2, plan 5).
void main() {
  test('the rule names each card', () {
    final expected = <String, SiteReaderCard>{
      siteHeaderCardId: SiteReaderCard.suggested,
      'description': SiteReaderCard.suggested,
      'notes': SiteReaderCard.private,
      'location': SiteReaderCard.suggested,
      'depth': SiteReaderCard.suggested,
      'altitude': SiteReaderCard.suggested,
      'difficulty': SiteReaderCard.suggested,
      'rating': SiteReaderCard.private,
      'hazards': SiteReaderCard.suggested,
      'access': SiteReaderCard.suggested,
      'features': SiteReaderCard.library,
      'marineLife': SiteReaderCard.library,
      'media': SiteReaderCard.private,
      'documents': SiteReaderCard.private,
      'tags': SiteReaderCard.suggested,
    };
    // Every card the page has is named here.
    expect({
      for (final card in siteEditCards.values) card.id,
    }, {...expected.keys}..remove(siteHeaderCardId));
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(siteReaderCardRule(key), value, reason: key);
    }
  });
}
