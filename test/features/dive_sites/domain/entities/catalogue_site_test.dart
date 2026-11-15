import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

void main() {
  test('a record is researched exactly when its trust says so', () {
    const verified = CatalogueSite(id: 'osm_node_1', name: 'A', source: 'osm');
    const researched = CatalogueSite(
      id: 'research_my_x',
      name: 'B',
      source: 'research',
      trust: CatalogueTrust.researched,
    );

    expect(verified.isResearched, isFalse);
    expect(researched.isResearched, isTrue);
  });
}
