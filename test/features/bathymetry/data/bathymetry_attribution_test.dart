import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_attribution.dart';

void main() {
  test('registers the credit the CC BY sources require', () async {
    // The seascape draws GMRT and EMODnet grids, both CC BY 4.0, so their
    // credit has to reach the app somewhere. This is a licence obligation,
    // so it is asserted rather than assumed.
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);

    BathymetryAttribution.registerLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final entry = entries.singleWhere(
      (e) => e.packages.contains(BathymetryAttribution.packageName),
    );
    final text = entry.paragraphs.map((p) => p.text).join(' ');

    expect(text, contains('GMRT'));
    expect(text, contains('EMODnet'));
    expect(text, contains('CC BY 4.0'));
    expect(text, contains('ETOPO 2022'));
    expect(text, contains('NCEI'));
    expect(text, contains('swissBATHY3D'));
    expect(text, contains('swisstopo'));
  });
}
