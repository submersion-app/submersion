import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/imported_profile_readers.dart';

void main() {
  group('profilePointFromImport', () {
    test('carries the computer-reported GF99 and N2 load', () {
      final point = profilePointFromImport({
        'timestamp': 60,
        'depth': 12.0,
        'gf99': 37,
        'n2Load': 54,
      });

      expect(point.gf99, 37);
      expect(point.n2Load, 54);
    });

    test('leaves them null when the sample has neither', () {
      final point = profilePointFromImport({'timestamp': 60, 'depth': 12.0});

      expect(point.gf99, isNull);
      expect(point.n2Load, isNull);
    });

    test('moves the sample by the offset', () {
      final point = profilePointFromImport({
        'timestamp': 60,
        'depth': 12.0,
      }, offsetSeconds: 30);

      expect(point.timestamp, 90);
      expect(point.depth, 12.0);
    });
  });
}
