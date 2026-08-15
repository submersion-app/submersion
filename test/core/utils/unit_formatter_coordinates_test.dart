import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  setUp(() => Intl.defaultLocale = 'en_US');

  test('renders in the diver-selected format', () {
    const dd = UnitFormatter(AppSettings());
    expect(
      dd.formatCoordinates(20.361944, -87.029722),
      '20.361944° N, 87.029722° W',
    );

    const mgrs = UnitFormatter(
      AppSettings(coordinateFormat: CoordinateFormat.mgrs),
    );
    expect(mgrs.formatCoordinates(20.361944, -87.029722), '16Q DH 96898 51535');
  });

  test('renders the placeholder when either axis is missing', () {
    const formatter = UnitFormatter(AppSettings());
    expect(formatter.formatCoordinates(null, -87.029722), '--');
    expect(formatter.formatCoordinates(20.361944, null), '--');
    expect(formatter.formatCoordinates(null, null), '--');
  });

  test('single-axis helpers follow the same preference', () {
    const formatter = UnitFormatter(
      AppSettings(coordinateFormat: CoordinateFormat.degreesDecimalMinutes),
    );
    expect(formatter.formatLatitude(20.361944), "20° 21.717' N");
    expect(formatter.formatLongitude(-87.029722), "87° 01.783' W");
  });
}
