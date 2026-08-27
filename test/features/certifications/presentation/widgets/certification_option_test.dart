import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';

void main() {
  // These are not incidental value-type niceties: CertificationOption exists
  // solely so that DropdownButton, which matches its selection against item
  // values with ==, sees a distinct value for every row. If equality broke,
  // the dropdown would silently select the wrong row or trip its
  // exactly-one-match assert.
  group('CertificationOption equality', () {
    test('two values wrapping the same level are equal', () {
      expect(
        const CertificationOption.value(CertificationLevel.openWater),
        const CertificationOption.value(CertificationLevel.openWater),
      );
    });

    test('values wrapping different levels are not equal', () {
      expect(
        const CertificationOption.value(CertificationLevel.openWater),
        isNot(const CertificationOption.value(CertificationLevel.rescue)),
      );
    });

    test('the null "not specified" value equals itself', () {
      expect(
        const CertificationOption.value(null),
        const CertificationOption.value(null),
      );
    });

    test('a header never equals another header', () {
      expect(
        const CertificationOption.header('progression'),
        isNot(const CertificationOption.header('specialties')),
      );
    });

    test('a header never equals the "not specified" value', () {
      // The bug this type prevents: with null-valued headers, all three of
      // these collided and DropdownButton's assert fired.
      expect(
        const CertificationOption.header('progression'),
        isNot(const CertificationOption.value(null)),
      );
    });

    test('every row of a realistic menu carries a distinct value', () {
      const rows = [
        CertificationOption.value(null),
        CertificationOption.header('progression'),
        CertificationOption.value(CertificationLevel.openWater),
        CertificationOption.value(CertificationLevel.rescue),
        CertificationOption.header('specialties'),
        CertificationOption.value(CertificationLevel.nitrox),
        CertificationOption.value(CertificationLevel.other),
      ];

      expect(rows.toSet(), hasLength(rows.length));
    });
  });

  group('CertificationOption hashCode', () {
    test('agrees with equality', () {
      expect(
        const CertificationOption.value(CertificationLevel.cave).hashCode,
        const CertificationOption.value(CertificationLevel.cave).hashCode,
      );
      expect(
        const CertificationOption.header('progression').hashCode,
        const CertificationOption.header('progression').hashCode,
      );
    });

    test('distinguishes a header from a value', () {
      expect(
        const CertificationOption.header('specialties').hashCode,
        isNot(const CertificationOption.value(null).hashCode),
      );
    });
  });
}
