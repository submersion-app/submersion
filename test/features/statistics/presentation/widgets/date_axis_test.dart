import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/presentation/widgets/date_axis.dart';

void main() {
  test('bounds are the range endpoints as epoch milliseconds', () {
    final first = DateTime.utc(2024, 1, 1);
    final last = DateTime.utc(2024, 12, 31);

    final axis = DateAxis.forRange(first, last);

    expect(axis.min, first.millisecondsSinceEpoch.toDouble());
    expect(axis.max, last.millisecondsSinceEpoch.toDouble());
  });

  test('a multi-year range ticks by year', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2020, 3, 5),
      DateTime.utc(2026, 8, 20),
    );

    expect(axis.granularity, DateAxisGranularity.year);
    expect(axis.ticks.every((t) => t.month == 1 && t.day == 1), isTrue);
    expect(axis.ticks.first.year, greaterThanOrEqualTo(2020));
    expect(axis.ticks.last.year, lessThanOrEqualTo(2026));
  });

  test('a range of about two years ticks by quarter', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2025, 12, 31),
    );

    expect(axis.granularity, DateAxisGranularity.quarter);
    expect(axis.ticks.every((t) => t.month % 3 == 1 && t.day == 1), isTrue);
  });

  test('a range of a few months ticks by month', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 5, 31),
    );

    expect(axis.granularity, DateAxisGranularity.month);
    expect(axis.ticks.every((t) => t.day == 1), isTrue);
  });

  test('a range of a few weeks ticks by day', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 1, 20),
    );

    expect(axis.granularity, DateAxisGranularity.day);
    expect(axis.ticks, isNotEmpty);
  });

  test('every tick lies inside the bounds', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2020, 3, 5),
      DateTime.utc(2026, 8, 20),
    );

    for (final tick in axis.ticks) {
      final ms = tick.millisecondsSinceEpoch.toDouble();
      expect(ms, greaterThanOrEqualTo(axis.min));
      expect(ms, lessThanOrEqualTo(axis.max));
    }
  });

  test('a single-instant range still yields a drawable axis', () {
    final only = DateTime.utc(2024, 6, 1);

    final axis = DateAxis.forRange(only, only);

    expect(axis.max, greaterThan(axis.min));
    expect(axis.ticks, isNotEmpty);
  });

  test('ticks are strictly increasing', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2021, 6, 1),
      DateTime.utc(2026, 6, 1),
    );

    for (var i = 1; i < axis.ticks.length; i++) {
      expect(axis.ticks[i].isAfter(axis.ticks[i - 1]), isTrue);
    }
  });

  group('showsLabelAt', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 9, 15),
    );

    test('labels both bounds', () {
      expect(axis.showsLabelAt(axis.min), isTrue);
      expect(axis.showsLabelAt(axis.max), isTrue);
    });

    test('refuses anything outside the bounds', () {
      expect(axis.showsLabelAt(axis.min - 1), isFalse);
      expect(axis.showsLabelAt(axis.max + 1), isFalse);
    });

    test('suppresses a label that would crowd the upper bound', () {
      // fl_chart draws the max label regardless, so a derived label a sliver
      // before it renders as one run of jammed text.
      expect(axis.showsLabelAt(axis.max - axis.labelInterval * 0.1), isFalse);
    });

    test('suppresses a label that would crowd the lower bound', () {
      expect(axis.showsLabelAt(axis.min + axis.labelInterval * 0.1), isFalse);
    });

    test('keeps a label a full interval clear of the bounds', () {
      expect(axis.showsLabelAt(axis.min + axis.labelInterval), isTrue);
      expect(axis.showsLabelAt(axis.max - axis.labelInterval), isTrue);
    });
  });

  group('labelFor', () {
    /// Every label fl_chart would draw: the bounds plus each interval slot.
    List<String> drawnLabels(DateAxis axis) {
      final out = <String>[];
      for (var v = axis.min; v <= axis.max; v += axis.labelInterval) {
        final label = axis.labelFor(v);
        if (label != null) out.add(label);
      }
      final last = axis.labelFor(axis.max);
      if (last != null && (out.isEmpty || out.last != last)) out.add(last);
      return out;
    }

    test('never repeats a month across adjacent slots', () {
      // Sep through May. labelInterval is uniform but months are not, so the
      // step drifts and two adjacent slots land in the same month.
      final axis = DateAxis.forRange(
        DateTime.utc(2025, 9, 1),
        DateTime.utc(2026, 5, 1),
      );

      final labels = drawnLabels(axis);

      expect(labels, isNotEmpty);
      expect(
        labels.length,
        labels.toSet().length,
        reason: 'duplicate labels: $labels',
      );
    });

    test('never repeats a year across adjacent slots', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2019, 4, 1),
        DateTime.utc(2026, 8, 1),
      );

      final labels = drawnLabels(axis);

      expect(labels.length, labels.toSet().length, reason: '$labels');
    });

    test('returns null outside the bounds', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 9, 1),
      );

      expect(axis.labelFor(axis.min - 1), isNull);
      expect(axis.labelFor(axis.max + 1), isNull);
    });

    test('labels the lower bound', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 9, 1),
      );

      expect(axis.labelFor(axis.min), isNotNull);
    });
  });

  group('year on every label', () {
    List<String> drawn(DateAxis axis) {
      final out = <String>[];
      for (var v = axis.min; v <= axis.max; v += axis.labelInterval) {
        final label = axis.labelFor(v);
        if (label != null) out.add(label);
      }
      return out;
    }

    test('every month label carries an abbreviated year', () {
      // Spelling the year only where it changed left one long label among
      // short ones, which read as ragged.
      final axis = DateAxis.forRange(
        DateTime.utc(2025, 9, 1),
        DateTime.utc(2026, 5, 1),
      );

      final labels = drawn(axis);

      expect(labels, isNotEmpty);
      for (final label in labels) {
        expect(
          RegExp(r"'\d{2}$").hasMatch(label),
          isTrue,
          reason: 'no year on $label',
        );
      }
    });

    test('the year is two digits, not four', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2025, 9, 1),
        DateTime.utc(2026, 5, 1),
      );

      for (final label in drawn(axis)) {
        expect(label.contains('2025'), isFalse, reason: label);
        expect(label.contains('2026'), isFalse, reason: label);
      }
    });

    test('labels stay distinct across a year boundary', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2025, 9, 1),
        DateTime.utc(2026, 5, 1),
      );

      final labels = drawn(axis);
      expect(labels.length, labels.toSet().length, reason: '$labels');
    });

    test('year granularity stays a plain four-digit year', () {
      final axis = DateAxis.forRange(
        DateTime.utc(2019, 1, 1),
        DateTime.utc(2026, 1, 1),
      );

      expect(axis.granularity, DateAxisGranularity.year);
      for (final label in drawn(axis)) {
        expect(RegExp(r'^\d{4}$').hasMatch(label), isTrue, reason: label);
      }
    });
  });
}
