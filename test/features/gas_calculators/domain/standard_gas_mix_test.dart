import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/standard_gas_mix.dart';

void main() {
  group('standardGasMixes', () {
    test('every entry is a distinct O2/He pair', () {
      final pairs = standardGasMixes.map((m) => (m.o2Percent, m.hePercent));
      expect(pairs.toSet(), hasLength(standardGasMixes.length));
    });

    test('every entry is a physically valid mix', () {
      for (final mix in standardGasMixes) {
        expect(
          mix.o2Percent,
          inInclusiveRange(1, 100),
          reason: '${mix.name} O2',
        );
        expect(
          mix.hePercent,
          greaterThanOrEqualTo(0),
          reason: '${mix.name} He',
        );
        expect(
          mix.o2Percent + mix.hePercent,
          lessThanOrEqualTo(100),
          reason: '${mix.name} O2+He',
        );
      }
    });

    test('isTrimix is true exactly for entries carrying helium', () {
      for (final mix in standardGasMixes) {
        expect(mix.isTrimix, mix.hePercent > 0, reason: mix.name);
      }
    });

    test('has the nineteen researched entries (issue #3117)', () {
      expect(standardGasMixes, hasLength(19));
    });

    test('every category in the issue is represented', () {
      expect(standardGasMixes.map((m) => m.category).toSet(), {
        StandardGasCategory.nitrox,
        StandardGasCategory.bottomGas,
        StandardGasCategory.decoGas,
      });
    });

    test('a named entry carries the associations the research found', () {
      final ean32 = standardGasMixes.firstWhere((m) => m.name == 'EAN32');
      expect(ean32.associations, ['NOAA']);

      final techTrimix1845 = standardGasMixes.firstWhere(
        (m) => m.o2Percent == 18 && m.hePercent == 45,
      );
      expect(techTrimix1845.associations, ['GUE', 'IANTD']);

      // App-internal entries carry no association, per the research.
      final trimix1835 = standardGasMixes.firstWhere(
        (m) => m.o2Percent == 18 && m.hePercent == 35,
      );
      expect(trimix1835.associations, isEmpty);
    });
  });
}
