import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/equipment_usage_builder.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

final _today = DateTime.utc(2026, 11, 27);

EquipmentExposureSample _s(
  DateTime date, {
  int minutes = 60,
  DiveMode mode = DiveMode.oc,
}) => EquipmentExposureSample(
  date: date,
  durationSeconds: minutes * 60,
  diveMode: mode,
);

EquipmentUsageHistory _build(
  List<EquipmentExposureSample> samples, {
  ExposureClassifier classifier = const ExposureClassifier(),
}) =>
    buildUsageHistory(samples: samples, classifier: classifier, today: _today);

void main() {
  group('buildUsageHistory', () {
    test('monthly holds twelve buckets ending with the current month', () {
      final history = _build([_s(DateTime.utc(2026, 11, 2))]);

      expect(history.monthly, hasLength(12));
      expect(history.monthly.first.start, DateTime.utc(2025, 12));
      expect(history.monthly.last.start, DateTime.utc(2026, 11));
    });

    test('dives and hours land in their calendar month', () {
      final history = _build([
        _s(DateTime.utc(2026, 11, 2, 9)),
        _s(DateTime.utc(2026, 11, 20, 23, 50), minutes: 30),
        _s(DateTime.utc(2026, 3, 5)),
      ]);

      expect(history.monthly.last.dives, 2);
      expect(history.monthly.last.hours, closeTo(1.5, 1e-9));
      final march = history.monthly.singleWhere(
        (b) => b.start == DateTime.utc(2026, 3),
      );
      expect(march.dives, 1);
      final others = history.monthly.where(
        (b) =>
            b.start != DateTime.utc(2026, 3) &&
            b.start != DateTime.utc(2026, 11),
      );
      expect(others.every((b) => b.dives == 0 && b.hours == 0), isTrue);
      expect(history.divesLast12Months, 3);
    });

    test('a dive on the first day of the window counts, the day before does '
        'not', () {
      final history = _build([
        _s(DateTime.utc(2025, 12, 1, 6)),
        _s(DateTime.utc(2025, 11, 30, 22)),
      ]);

      expect(history.monthly.first.dives, 1);
      expect(history.divesLast12Months, 1);
    });

    test('yearly runs from the first dive year to the current year with '
        'empty years', () {
      final history = _build([
        _s(DateTime.utc(2019, 6, 1)),
        _s(DateTime.utc(2019, 7, 1)),
        _s(DateTime.utc(2026, 2, 1)),
      ]);

      expect(history.yearly, hasLength(8));
      expect(history.yearly.first.start, DateTime.utc(2019));
      expect(history.yearly.first.dives, 2);
      expect(history.yearly.last.start, DateTime.utc(2026));
      expect(history.yearly.last.dives, 1);
      expect(history.yearly.sublist(1, 7).every((b) => b.dives == 0), isTrue);
    });

    test('no samples gives the empty history', () {
      expect(_build(const []), EquipmentUsageHistory.empty);
    });

    test('bucket hours follow the classifier', () {
      final history = _build([
        _s(DateTime.utc(2026, 11, 3), mode: DiveMode.ccr),
        _s(DateTime.utc(2026, 11, 4)),
      ], classifier: const ExposureClassifier(loopTimeOnly: true));

      expect(history.monthly.last.dives, 2);
      expect(history.monthly.last.hours, closeTo(1.0, 1e-9));
    });

    test('a future-dated sample reads as today and lands in the current '
        'month', () {
      final history = _build([_s(DateTime.utc(2026, 11, 29))]);

      expect(history.lastDive, DateTime.utc(2026, 11, 29));
      expect(history.lastDivedAgo, (unit: LastDivedUnit.today, count: 0));
      expect(history.monthly.last.dives, 1);
      expect(history.yearly, hasLength(1));
    });

    test('a sample in a later year than today counts in the current year', () {
      final history = _build([_s(DateTime.utc(2027, 1, 2))]);

      expect(history.yearly.single.start, DateTime.utc(2026));
      expect(history.yearly.single.dives, 1);
      expect(history.monthly.last.dives, 1);
    });

    test('last dive is the latest sample, whatever the order', () {
      final history = _build([
        _s(DateTime.utc(2026, 6, 1)),
        _s(DateTime.utc(2026, 9, 1)),
        _s(DateTime.utc(2026, 1, 1)),
      ]);

      expect(history.lastDive, DateTime.utc(2026, 9, 1));
      expect(history.lastDivedAgo, (unit: LastDivedUnit.months, count: 2));
    });
  });

  group('lastDivedAgo', () {
    LastDivedAgo ago(DateTime last) =>
        lastDivedAgo(lastDive: last, today: _today);

    test('the same day is today, whatever the time', () {
      expect(ago(DateTime.utc(2026, 11, 27, 23, 59)), (
        unit: LastDivedUnit.today,
        count: 0,
      ));
    });

    test('up to thirty days counts days', () {
      expect(ago(DateTime.utc(2026, 11, 26, 22)), (
        unit: LastDivedUnit.days,
        count: 1,
      ));
      expect(ago(DateTime.utc(2026, 10, 28)), (
        unit: LastDivedUnit.days,
        count: 30,
      ));
    });

    test('past thirty days counts whole months', () {
      expect(ago(DateTime.utc(2026, 10, 26)), (
        unit: LastDivedUnit.months,
        count: 1,
      ));
      expect(ago(DateTime.utc(2025, 11, 28)), (
        unit: LastDivedUnit.months,
        count: 11,
      ));
      expect(ago(DateTime.utc(2024, 11, 28)), (
        unit: LastDivedUnit.months,
        count: 23,
      ));
    });

    test('from two years counts whole years', () {
      expect(ago(DateTime.utc(2024, 11, 27)), (
        unit: LastDivedUnit.years,
        count: 2,
      ));
      expect(ago(DateTime.utc(2014, 2, 3)), (
        unit: LastDivedUnit.years,
        count: 12,
      ));
    });

    test('thirty-one days into a short month is still one month', () {
      // Jan 31 to Mar 3 is 31 days (2027 is not a leap year), with
      // today.day < last.day: one whole month, never zero.
      expect(
        lastDivedAgo(
          lastDive: DateTime.utc(2027, 1, 31),
          today: DateTime.utc(2027, 3, 3),
        ),
        (unit: LastDivedUnit.months, count: 1),
      );
    });
  });
}
