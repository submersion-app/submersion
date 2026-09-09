import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';

/// These helpers resolve against `Intl.defaultLocale`, a process global the
/// app sets from the diver's language at `lib/app.dart`. Pin it per test so
/// the assertions do not ride on intl's implicit en_US fallback. Number
/// symbols are statically bundled, so no async initialization is needed here.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('formatFixedForDisplay', () {
    test('uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(12.5, 1), '12,5');
      Intl.defaultLocale = 'fr';
      expect(formatFixedForDisplay(12.5, 1), '12,5');
      Intl.defaultLocale = 'en_US';
      expect(formatFixedForDisplay(12.5, 1), '12.5');
    });

    test('keeps trailing zeros, unlike the input seeding helpers', () {
      // Display precision is load-bearing: "200.0 bar" says the reading was
      // taken to a tenth. formatDecimalForInput drops that zero on purpose
      // because a field wants "200", which is why display needs its own helper.
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(200, 1), '200,0');
      expect(formatFixedForDisplay(2, 2), '2,00');
    });

    test('renders whole numbers without a separator', () {
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(1250, 0), '1250');
    });

    test('adds no grouping separator', () {
      // Grouping is a separate decision from the decimal separator, and #1683
      // is only about the latter. formatAltitude keeps its own NumberFormat
      // for the places that do want groups.
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(1250.5, 1), '1250,5');
    });

    test('localises the minus sign alongside the separator', () {
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(-3.5, 1), '-3,5');
    });

    test('rounds the way toStringAsFixed does', () {
      Intl.defaultLocale = 'de';
      expect(formatFixedForDisplay(25.5555, 1), '25,6');
      expect(formatFixedForDisplay(25.04, 0), '25');
    });

    test(
      'renders the shortest round-tripping decimal, not the binary value',
      () {
        // NumberFormat renders the exact binary value, so a fraction cap raised
        // far enough to stop it rounding makes it emit noise: 12.05 becomes
        // "12.050000000000001". Going through toStringAsFixed avoids that.
        Intl.defaultLocale = 'de';
        expect(formatFixedForDisplay(12.05, 2), '12,05');
      },
    );
  });

  group('localiseDecimalText', () {
    test('swaps an already-formatted ASCII number', () {
      Intl.defaultLocale = 'de';
      expect(localiseDecimalText('25.6'), '25,6');
      expect(localiseDecimalText('-3.5'), '-3,5');
    });

    test('leaves a number with no fractional part alone', () {
      Intl.defaultLocale = 'de';
      expect(localiseDecimalText('26'), '26');
    });

    test('is a no-op under a dot-decimal locale', () {
      Intl.defaultLocale = 'en_US';
      expect(localiseDecimalText('25.6'), '25.6');
    });
  });

  group('formatDecimalForDisplay', () {
    test('uses the locale decimal separator', () {
      Intl.defaultLocale = 'de';
      expect(formatDecimalForDisplay(200.0), '200,0');
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForDisplay(200.0), '200.0');
    });

    test('keeps a trailing zero where the input form drops it', () {
      // Asserted as a pair on purpose: these two differ in exactly one way,
      // and it is load bearing. A field seeded "200.0" reads as a
      // half-finished edit, so the input form strips it; a recorded reading
      // of 200.0 bar states a precision the diver logged, so the display form
      // keeps it. Routing a display through the input helper silently drops
      // a decimal the tile was claiming.
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForDisplay(200.0), '200.0');
      expect(formatDecimalForInput(200.0), '200');
    });

    test('localises a negative value', () {
      Intl.defaultLocale = 'de';
      expect(formatDecimalForDisplay(-3.5), '-3,5');
    });

    test('omits grouping separators, matching the input form', () {
      Intl.defaultLocale = 'de';
      expect(formatDecimalForDisplay(1250.5), '1250,5');
    });

    test('does not silently truncate precision', () {
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForDisplay(12.345678), '12.345678');
    });

    test('spells out a magnitude that stringifies in exponent notation', () {
      // No diver can read "1e+21" off a checklist tile.
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForDisplay(1e21), isNot(contains('e')));
    });

    test('renders nothing for a non-finite value', () {
      // Unreachable through parseUserDecimal, which rejects both, but the
      // display form must not put "NaN" in front of a diver either way.
      Intl.defaultLocale = 'en_US';
      expect(formatDecimalForDisplay(double.nan), '');
      expect(formatDecimalForDisplay(double.infinity), '');
    });
  });
}
