import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // The weekday goes through Intl.defaultLocale: a process global that a test
  // sharing this isolate may leave set.
  late String? previousLocale;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  group('formatNoFlyWhen', () {
    // A Thursday in every zone, built locally so it reads the same wherever
    // the suite runs.
    final instant = DateTime(2027, 1, 7, 15, 5).toUtc();

    test('reads a true instant on the device clock', () {
      const units = UnitFormatter(AppSettings());
      expect(formatNoFlyWhen(instant, units), 'Thu 3:05 PM');
    });

    test('follows the diver\'s time format', () {
      const units = UnitFormatter(
        AppSettings(timeFormat: TimeFormat.twentyFourHour),
      );
      expect(formatNoFlyWhen(instant, units), 'Thu 15:05');
    });
  });
}
