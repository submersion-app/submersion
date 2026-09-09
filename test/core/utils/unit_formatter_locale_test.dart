import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// UnitFormatter renders its digits with `toStringAsFixed`, which implements
/// the Dart literal grammar and always emits '.' (#1683). Input was made
/// locale-aware in #1091, so before this fix the two halves of a numeric field
/// disagreed: a German diver typed "12,5" and read back "12.5 m".
///
/// These assertions pin `Intl.defaultLocale`, the process global the app sets
/// from the diver's language at `lib/app.dart`. A test that set only a
/// `MaterialApp` locale would pass against unfixed code. Number symbols are
/// statically bundled, so no async initialization is needed here - unlike date
/// formatting.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
      altitudeUnit: AltitudeUnit.feet,
    ),
  );

  group('comma-decimal locale', () {
    test('depth uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatDepth(12.5), '12,5m');
      Intl.defaultLocale = 'fr';
      expect(metric.formatDepth(12.5), '12,5m');
    });

    test('temperature uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatTemperature(25.5555), '25,6°C');
    });

    test('temperature still drops a zero decimal', () {
      // _trimTrailingZeros matches a literal '.', so it has to run before
      // localisation. Under de the '.' it would match afterwards is the
      // grouping separator, and "26.0" would survive as "26,0" or lose a digit.
      Intl.defaultLocale = 'de';
      expect(metric.formatTemperature(26.0), '26°C');
      expect(metric.formatTemperature(-3.0), '-3°C');
    });

    test('pressure uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatPressure(207.5, decimals: 1), '207,5 bar');
      expect(metric.formatPressureValue(207.5, decimals: 1), '207,5');
    });

    test('volume uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatVolume(11.5, decimals: 1), '11,5 L');
    });

    test('tank volume uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatTankVolume(1.5, 200), '1,5 L');
      // The trailing-zero trim runs first, so a whole cylinder keeps no
      // separator at all.
      expect(metric.formatTankVolume(12.0, 232), '12 L');
    });

    test('SAC and RMV use the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatSac(1.5), '1,5 bar/min');
      expect(metric.formatRmv(16.8), '16,8 L/min');
      expect(imperial.formatRmv(16.8), '0,59 cuft/min');
    });

    test('weight uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatWeight(5.5), '5,5 kg');
    });

    test('barometric pressure uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatBarometricPressure(1.013), '1,013 bar');
      expect(
        metric.formatBarometricPressureMbar(1.013, decimals: 1),
        '1013,0 mbar',
      );
    });

    test('surface pressure uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      // Metric renders whole mbar, so only the imperial inHg branch carries a
      // fraction to localise.
      expect(metric.formatSurfacePressure(1.013), '1013 mbar');
      expect(imperial.formatSurfacePressure(1.013), '29,91 inHg');
    });

    test('wind speed and speed use the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatWindSpeed(5.0, decimals: 1), '18,0 km/h');
      expect(metric.formatSpeed(1.5), '5,4 km/h');
    });

    test('distance uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatDistance(12.5, decimals: 1), '12,5m');
    });

    test('geo distance uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(metric.formatGeoDistance(2500), '2,5 km');
    });
  });

  group('dot-decimal locale', () {
    test('renders unchanged ASCII output', () {
      Intl.defaultLocale = 'en_US';
      expect(metric.formatDepth(12.5), '12.5m');
      expect(metric.formatTemperature(25.5555), '25.6°C');
      expect(metric.formatSac(1.5), '1.5 bar/min');
      expect(metric.formatBarometricPressure(1.013), '1.013 bar');
    });
  });

  group('coordinates', () {
    test('stay ASCII under a comma locale', () {
      // Deliberate carve-out: coordinate text is a dot-based internal source
      // of truth shared with the DMS/DDM/UTM/MGRS parsers, and a comma is
      // also the lat/lon separator there.
      Intl.defaultLocale = 'de';
      expect(metric.formatCoordinates(12.5, -3.25), contains('.'));
    });
  });
}
