import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/table_editor/presentation/widgets/table_editor_tabs.dart';

/// A column has a filter menu wherever its entity has a query field (#3422).
void main() {
  test('every mapped column names a real query field', () {
    expect(
      kSiteColumnKeys.values.where((k) => siteQueryEntity.field(k) == null),
      isEmpty,
    );
    expect(
      kCenterColumnKeys.values.where(
        (k) => diveCenterQueryEntity.field(k) == null,
      ),
      isEmpty,
    );
  });

  test('the location columns of a site can be filtered', () {
    expect(
      kSiteColumnKeys.keys,
      containsAll([SiteField.country, SiteField.region, SiteField.island]),
    );
  });
}
