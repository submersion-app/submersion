import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test(
    'every CertificationAgency has a distinct primary and secondary color',
    () {
      for (final agency in CertificationAgency.values) {
        // Both switches are exhaustive by value; touching each one keeps the
        // new FFESSM arms (and any future agency) covered.
        expect(agency.primaryColor, isA<Color>());
        expect(agency.secondaryColor, isA<Color>());
        expect(
          agency.primaryColor,
          isNot(equals(agency.secondaryColor)),
          reason: '${agency.name}: the gradient needs two colors',
        );
      }
    },
  );

  test('FFESSM carries its own brand blue', () {
    expect(CertificationAgency.ffessm.primaryColor, const Color(0xFF00529b));
    expect(CertificationAgency.ffessm.secondaryColor, const Color(0xFF1e88e5));
  });

  test('ACUC is navy and DAN is crimson (issue #690)', () {
    expect(CertificationAgency.acuc.primaryColor, const Color(0xFF0D3B7A));
    expect(CertificationAgency.acuc.secondaryColor, const Color(0xFF2E6BC4));
    expect(CertificationAgency.dan.primaryColor, const Color(0xFF9E1B32));
    expect(CertificationAgency.dan.secondaryColor, const Color(0xFFD23C52));
  });
}
