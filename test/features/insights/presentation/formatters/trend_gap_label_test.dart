import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/formatters/trend_gap_label.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('names every threshold', () {
    expect(trendGapThresholdLabel(TrendGapThreshold.off, en), 'Off');
    expect(trendGapThresholdLabel(TrendGapThreshold.months6, en), '6 months');
    expect(trendGapThresholdLabel(TrendGapThreshold.year1, en), '1 year');
    expect(trendGapThresholdLabel(TrendGapThreshold.years2, en), '2 years');
  });

  test('counts whole calendar months', () {
    expect(
      calendarMonthsBetween(
        DateTime.utc(2018, 6, 10),
        DateTime.utc(2025, 3, 20),
      ),
      81,
    );
    expect(
      calendarMonthsBetween(
        DateTime.utc(2018, 6, 20),
        DateTime.utc(2025, 3, 10),
      ),
      80,
    );
    expect(
      calendarMonthsBetween(DateTime.utc(2020, 1, 1), DateTime.utc(2020, 1, 1)),
      0,
    );
  });

  test('years and months render in that order', () {
    final start = DateTime.utc(2018, 6, 1);
    final end = DateTime.utc(2025, 3, 1);
    expect(trendGapLengthLabel(start, end, en), '6y 9m');
    expect(trendGapLengthLabel(start, end, AppLocalizationsDe()), '6 J 9 M');
  });

  test('whole years and short gaps drop the empty part', () {
    expect(
      trendGapLengthLabel(
        DateTime.utc(2018, 6, 1),
        DateTime.utc(2021, 6, 1),
        en,
      ),
      '3y',
    );
    expect(
      trendGapLengthLabel(
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2020, 8, 1),
        en,
      ),
      '7m',
    );
  });
}
