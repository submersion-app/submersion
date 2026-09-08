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
}
