import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/arb/app_localizations_zh.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();
  final zh = AppLocalizationsZh();

  group('splitElapsed', () {
    test('under an hour is whole minutes, seconds cut off', () {
      expect(splitElapsed(Duration.zero), (
        tier: ElapsedTier.minutes,
        major: 0,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(minutes: 59, seconds: 59)), (
        tier: ElapsedTier.minutes,
        major: 59,
        minor: 0,
      ));
    });

    test('an hour up to a day is hours and minutes', () {
      expect(splitElapsed(const Duration(hours: 1)), (
        tier: ElapsedTier.hoursMinutes,
        major: 1,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(hours: 23, minutes: 59)), (
        tier: ElapsedTier.hoursMinutes,
        major: 23,
        minor: 59,
      ));
    });

    test('a day up to a year is days and hours, minutes cut off', () {
      expect(splitElapsed(const Duration(days: 1)), (
        tier: ElapsedTier.daysHours,
        major: 1,
        minor: 0,
      ));
      // The two values from the issue's screenshot.
      expect(splitElapsed(const Duration(hours: 157, minutes: 42)), (
        tier: ElapsedTier.daysHours,
        major: 6,
        minor: 13,
      ));
      expect(splitElapsed(const Duration(hours: 6379, minutes: 45)), (
        tier: ElapsedTier.daysHours,
        major: 265,
        minor: 19,
      ));
      expect(splitElapsed(const Duration(days: 364, hours: 23, minutes: 59)), (
        tier: ElapsedTier.daysHours,
        major: 364,
        minor: 23,
      ));
    });

    test('a year and up is 365-day years and days, hours cut off', () {
      expect(splitElapsed(const Duration(days: 365)), (
        tier: ElapsedTier.yearsDays,
        major: 1,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(days: 400, hours: 23)), (
        tier: ElapsedTier.yearsDays,
        major: 1,
        minor: 35,
      ));
      expect(splitElapsed(const Duration(days: 730)), (
        tier: ElapsedTier.yearsDays,
        major: 2,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(days: 20 * 365 + 3)), (
        tier: ElapsedTier.yearsDays,
        major: 20,
        minor: 3,
      ));
    });

    test('a negative span reads as zero', () {
      expect(splitElapsed(const Duration(minutes: -90)), (
        tier: ElapsedTier.minutes,
        major: 0,
        minor: 0,
      ));
    });
  });

  group('formatElapsed', () {
    test('renders each tier in English', () {
      expect(formatElapsed(en, const Duration(minutes: 42)), '42 min');
      expect(
        formatElapsed(en, const Duration(hours: 5, minutes: 12)),
        '5h 12m',
      );
      expect(
        formatElapsed(en, const Duration(hours: 157, minutes: 42)),
        '6d 13h',
      );
      expect(formatElapsed(en, const Duration(days: 2)), '2d 0h');
      expect(formatElapsed(en, const Duration(days: 400)), '1y 35d');
      expect(formatElapsed(en, const Duration(days: 730)), '2y 0d');
    });

    test('uses each locale\'s own unit letters and order', () {
      expect(
        formatElapsed(de, const Duration(hours: 5, minutes: 12)),
        '5 h 12 min',
      );
      expect(
        formatElapsed(de, const Duration(hours: 157, minutes: 42)),
        '6T 13h',
      );
      expect(formatElapsed(de, const Duration(days: 400)), '1J 35T');
      expect(
        formatElapsed(zh, const Duration(hours: 157, minutes: 42)),
        '6天13小时',
      );
      expect(formatElapsed(zh, const Duration(days: 400)), '1年35天');
    });
  });

  group('formatElapsedExact', () {
    test('matches the two-unit form under a day', () {
      expect(formatElapsedExact(en, const Duration(minutes: 42)), '42 min');
      expect(
        formatElapsedExact(en, const Duration(hours: 5, minutes: 12)),
        '5h 12m',
      );
    });

    test('adds back the unit the two-unit form drops past a day', () {
      expect(
        formatElapsedExact(en, const Duration(hours: 157, minutes: 10)),
        '6d 13h 10m',
      );
      expect(
        formatElapsedExact(en, const Duration(hours: 157, minutes: 42)),
        '6d 13h 42m',
      );
      expect(
        formatElapsedExact(en, const Duration(days: 400, hours: 5)),
        '1y 35d 5h',
      );
      expect(
        formatElapsedExact(de, const Duration(hours: 157, minutes: 42)),
        '6T 13h 42 min',
      );
      expect(
        formatElapsedExact(zh, const Duration(days: 400, hours: 5)),
        '1年35天5小时',
      );
    });
  });

  group('formatElapsedEnglish', () {
    test('renders each tier with fixed English letters', () {
      expect(formatElapsedEnglish(const Duration(minutes: 45)), '45min');
      expect(formatElapsedEnglish(const Duration(minutes: 65)), '1h 5m');
      expect(
        formatElapsedEnglish(const Duration(hours: 157, minutes: 42)),
        '6d 13h',
      );
      expect(formatElapsedEnglish(const Duration(days: 400)), '1y 35d');
      expect(formatElapsedEnglish(const Duration(minutes: -5)), '0min');
    });
  });

  group('formatElapsedDays', () {
    test('leaves counts under a year to the caller', () {
      expect(formatElapsedDays(en, 0), isNull);
      expect(formatElapsedDays(en, 364), isNull);
    });

    test('renders a year or more as years and days', () {
      expect(formatElapsedDays(en, 365), '1y 0d');
      expect(formatElapsedDays(en, 400), '1y 35d');
      expect(formatElapsedDays(de, 400), '1J 35T');
    });
  });
}
