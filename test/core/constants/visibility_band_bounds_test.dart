import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';

void main() {
  test('legacy bands expose their true metric bounds', () {
    expect(Visibility.excellent.bandMinM, 30);
    expect(Visibility.excellent.bandMaxM, isNull);
    expect(Visibility.good.bandMinM, 15);
    expect(Visibility.good.bandMaxM, 30);
    expect(Visibility.moderate.bandMinM, 5);
    expect(Visibility.moderate.bandMaxM, 15);
    expect(Visibility.poor.bandMinM, isNull);
    expect(Visibility.poor.bandMaxM, 5);
  });

  test('unknown has no bounds at all', () {
    expect(Visibility.unknown.bandMinM, isNull);
    expect(Visibility.unknown.bandMaxM, isNull);
  });

  test('adjacent bands meet without gaps or overlap', () {
    expect(Visibility.poor.bandMaxM, Visibility.moderate.bandMinM);
    expect(Visibility.moderate.bandMaxM, Visibility.good.bandMinM);
    expect(Visibility.good.bandMaxM, Visibility.excellent.bandMinM);
  });

  test('displayName is unchanged, since it feeds data interchange', () {
    // environment_enum_display.dart documents that enum displayName stays
    // English on purpose: CSV/Excel export and the field extractor want a
    // stable, locale-independent value.
    expect(Visibility.excellent.displayName, 'Excellent (>30m / >100ft)');
    expect(Visibility.good.displayName, 'Good (15-30m / 50-100ft)');
    expect(Visibility.moderate.displayName, 'Moderate (5-15m / 15-50ft)');
    expect(Visibility.poor.displayName, 'Poor (<5m / <15ft)');
    expect(Visibility.unknown.displayName, 'Unknown');
  });

  test('the bounds match the ranges the display names advertise', () {
    // Guards against the bounds and the English label drifting apart.
    expect(Visibility.moderate.displayName, contains('5-15m'));
    expect(Visibility.moderate.bandMinM, 5);
    expect(Visibility.moderate.bandMaxM, 15);
  });
}
