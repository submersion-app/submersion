import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';

/// Each of the site's held lists is loaded as a sitting starts and names
/// the library field its write changes, in one table, so a list cannot be
/// added to one without the other (issue #4527, phase 2).
void main() {
  test('every held list names a library field, once', () {
    final keys = [for (final list in siteHeldLists) list.key];
    expect(keys.toSet(), hasLength(keys.length));
    for (final list in siteHeldLists) {
      expect(list.libraryFields, isNotEmpty, reason: list.key);
    }
  });

  test('the table holds the site lists', () {
    expect(
      {for (final list in siteHeldLists) list.key},
      {
        siteTypesList.key,
        siteTagsList.key,
        siteSpeciesList.key,
        siteFeaturesList.key,
      },
    );
  });
}
