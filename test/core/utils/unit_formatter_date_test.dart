import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // These assertions are formatted by intl, which resolves against
  // Intl.defaultLocale: a process global that app.dart sets from the app
  // locale. There is no MaterialApp here to pin it, so without this the
  // spelled months and the digits would ride on intl's implicit en_US
  // fallback. Pin it, and restore it so the global stays contained.
  //
  // Setting the global explicitly means intl stops using its built-in fallback
  // and demands real symbol data, so the locale must be initialized first.
  late String? previousLocale;

  // Symbol data does not depend on per-test state, so load it once.
  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  const monthFirst = UnitFormatter(
    AppSettings(dateFormat: DateFormatPreference.mmddyyyy),
  );
  const dayFirst = UnitFormatter(
    AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
  );

  group('formatMonthDayWithYear', () {
    // The list tiles compare against "now", so pin the reference year to keep
    // the expectations stable as the wall clock moves.
    final reference = DateTime(2026, 6, 1);

    test('omits the year inside the reference year', () {
      final date = DateTime(2026, 3, 15);
      expect(
        monthFirst.formatMonthDayWithYear(date, relativeTo: reference),
        'Mar 15',
      );
      expect(
        dayFirst.formatMonthDayWithYear(date, relativeTo: reference),
        '15 Mar',
      );
    });

    test('adds a full year outside the reference year', () {
      final date = DateTime(2024, 3, 15);
      expect(
        monthFirst.formatMonthDayWithYear(date, relativeTo: reference),
        'Mar 15, 2024',
      );
      expect(
        dayFirst.formatMonthDayWithYear(date, relativeTo: reference),
        '15 Mar 2024',
      );
    });

    test('adds a two-digit year when shortYear is set', () {
      final date = DateTime(2024, 3, 15);
      expect(
        monthFirst.formatMonthDayWithYear(
          date,
          shortYear: true,
          relativeTo: reference,
        ),
        "Mar 15 '24",
      );
      expect(
        dayFirst.formatMonthDayWithYear(
          date,
          shortYear: true,
          relativeTo: reference,
        ),
        "15 Mar '24",
      );
    });

    test('renders the placeholder for a null date', () {
      expect(monthFirst.formatMonthDayWithYear(null), '--');
    });
  });

  group('formatWeekdayMonthDay', () {
    final date = DateTime(2026, 3, 15);

    test('keeps the weekday first and orders the rest by preference', () {
      expect(monthFirst.formatWeekdayMonthDay(date), 'Sun, Mar 15');
      expect(dayFirst.formatWeekdayMonthDay(date), 'Sun, 15 Mar');
    });

    test('renders the placeholder for a null date', () {
      expect(monthFirst.formatWeekdayMonthDay(null), '--');
    });
  });

  group('formatMonthYear', () {
    final date = DateTime(2026, 3, 15);

    test('drops the day from the diver preference, keeping its shape', () {
      expect(monthFirst.formatMonthYear(date), '03/2026');
      expect(dayFirst.formatMonthYear(date), '03/2026');
      expect(
        const UnitFormatter(
          AppSettings(dateFormat: DateFormatPreference.yyyymmdd),
        ).formatMonthYear(date),
        '2026-03',
      );
      expect(
        const UnitFormatter(
          AppSettings(dateFormat: DateFormatPreference.mmmDYYYY),
        ).formatMonthYear(date),
        'Mar 2026',
      );
      expect(
        const UnitFormatter(
          AppSettings(dateFormat: DateFormatPreference.dMMMYYYY),
        ).formatMonthYear(date),
        'Mar 2026',
      );
      expect(
        const UnitFormatter(
          AppSettings(dateFormat: DateFormatPreference.ddmmyyyyDots),
        ).formatMonthYear(date),
        '03.2026',
      );
    });

    test('renders the placeholder for a null date', () {
      expect(monthFirst.formatMonthYear(null), '--');
    });
  });

  group('static patterns', () {
    test('monthDayPattern follows the day-first preference', () {
      expect(
        UnitFormatter.monthDayPattern(DateFormatPreference.mmddyyyy),
        'MMM d',
      );
      expect(
        UnitFormatter.monthDayPattern(DateFormatPreference.ddmmyyyy),
        'd MMM',
      );
    });

    // #1512 follow-up: the chart axis first derived this from `isDayFirst`,
    // which is true for the ISO preference too, so an ISO diver got a
    // day-first "8/10" and the dotted preference lost its dots.
    test('numericMonthDayPattern keeps the order and the separator', () {
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.mmddyyyy),
        'M/d',
      );
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.ddmmyyyy),
        'd/M',
      );
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.yyyymmdd),
        'M-d',
      );
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.ddmmyyyyDots),
        'd.M',
      );
      // The spelled-out preferences separate with a space or a comma, which
      // does not read as a date on a cramped axis, so they take a slash.
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.mmmDYYYY),
        'M/d',
      );
      expect(
        UnitFormatter.numericMonthDayPattern(DateFormatPreference.dMMMYYYY),
        'd/M',
      );
    });

    test('monthYearPattern removes the day and its separator', () {
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.mmddyyyy),
        'MM/yyyy',
      );
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.ddmmyyyy),
        'MM/yyyy',
      );
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.yyyymmdd),
        'yyyy-MM',
      );
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.mmmDYYYY),
        'MMM yyyy',
      );
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.dMMMYYYY),
        'MMM yyyy',
      );
      expect(
        UnitFormatter.monthYearPattern(DateFormatPreference.ddmmyyyyDots),
        'MM.yyyy',
      );
    });

    test('weekdayMonthDayPattern prefixes the weekday in both orders', () {
      expect(
        UnitFormatter.weekdayMonthDayPattern(DateFormatPreference.mmddyyyy),
        'EEE, MMM d',
      );
      expect(
        UnitFormatter.weekdayMonthDayPattern(DateFormatPreference.ddmmyyyy),
        'EEE, d MMM',
      );
    });
  });
}
