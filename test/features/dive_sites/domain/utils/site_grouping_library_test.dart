import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';

void main() {
  test('siteLibraryKey groups by library id, personal sites to noGroupKey', () {
    expect(
      siteLibraryKey(
        const DiveSite(id: '1', name: 'a', sharedLibraryId: 'library-1'),
      ),
      'library-1',
    );
    expect(siteLibraryKey(const DiveSite(id: '2', name: 'b')), noGroupKey);
  });

  test('the library mode groups by library with no inner axis', () {
    expect(outerKeyOfMode(SiteGroupBy.library), siteLibraryKey);
    expect(innerKeyOfMode(SiteGroupBy.library), isNull);
    expect(bundlesUnlabeledInner(SiteGroupBy.library), isFalse);
  });
}
