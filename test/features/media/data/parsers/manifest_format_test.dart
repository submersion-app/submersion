import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('ManifestFormat', () {
    test('all known names round-trip via fromString', () {
      for (final f in ManifestFormat.values) {
        expect(ManifestFormat.fromString(f.name), equals(f));
      }
    });

    test('fromString returns null for unknown', () {
      expect(ManifestFormat.fromString('xml'), isNull);
      expect(ManifestFormat.fromString(''), isNull);
      expect(ManifestFormat.fromString(null), isNull);
    });

    test('displayName is human-readable', () {
      expect(ManifestFormat.atom.displayName, 'Atom / RSS');
      expect(ManifestFormat.json.displayName, 'JSON');
      expect(ManifestFormat.csv.displayName, 'CSV');
    });
  });
}
