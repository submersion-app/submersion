import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

void main() {
  group('LinkRefIndex', () {
    test('classifies a site-ref correctly', () {
      final index = LinkRefIndex({
        'site-a': LinkRefKind.site,
        'buddy-a': LinkRefKind.buddy,
        'gear-a': LinkRefKind.gear,
      });
      expect(index.kindOf('site-a'), LinkRefKind.site);
      expect(index.kindOf('buddy-a'), LinkRefKind.buddy);
      expect(index.kindOf('gear-a'), LinkRefKind.gear);
      expect(index.kindOf('unknown'), LinkRefKind.unknown);
    });

    test('handles null ref gracefully', () {
      final index = LinkRefIndex(const {});
      expect(index.kindOf(null), LinkRefKind.unknown);
    });
  });
}
