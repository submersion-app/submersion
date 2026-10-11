import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/query/dive_cell_filter_options.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// A cell's filter menu holds the dive that was clicked (#2984).
void main() {
  const metric = UnitFormatter(AppSettings());
  final imperial = UnitFormatter(
    const AppSettings().copyWith(depthUnit: DepthUnit.feet),
  );
  const feetPrefs = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );
  final base = Dive(id: 'd', dateTime: DateTime.utc(2026, 4, 1, 9));

  List<CellFilterOption> options(
    DiveField f,
    Dive d, {
    UnitFormatter units = metric,
    UnitPrefs prefs = kMetricPrefs,
    Map<String, Duration?> si = const {},
  }) => diveCellFilterOptions(
    field: f,
    dive: d,
    units: units,
    prefs: prefs,
    surfaceIntervals: si,
  );

  (double, double) betweenOf(QueryNode n) {
    final items = ((n as ConditionNode).value! as ListValue).items;
    return ((items[0] as NumberValue).value, (items[1] as NumberValue).value);
  }

  test('a site offers Only and Exclude by id', () {
    final d = base.copyWith(
      site: const DiveSite(id: 's1', name: 'Salt Pier'),
    );
    final o = options(DiveField.siteName, d);
    expect(o.map((x) => x.kind), [CellFilterKind.only, CellFilterKind.exclude]);
    expect(
      o.first.rule,
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s1', 'Salt Pier'),
      ),
    );
    expect(o.last.rule, NotNode(o.first.rule));
    expect(o.first.valueLabel, 'Salt Pier');
  });

  test('an empty cell offers none and any', () {
    final o = options(DiveField.siteName, base);
    expect(o.map((x) => x.kind), [
      CellFilterKind.noValue,
      CellFilterKind.anyValue,
    ]);
    expect((o.first.rule as ConditionNode).op, QueryOp.isEmpty);
  });

  test('a depth Only keeps the clicked dive inside the displayed step', () {
    final o = options(DiveField.maxDepth, base.copyWith(maxDepth: 23.4167));
    expect(o.map((x) => x.kind), [
      CellFilterKind.only,
      CellFilterKind.atLeast,
      CellFilterKind.atMost,
    ]);
    final (lo, hi) = betweenOf(o.first.rule);
    expect(lo, closeTo(23.35, 1e-9));
    expect(hi, closeTo(23.45, 1e-9));
    expect(o.first.valueLabel, metric.formatDepth(23.4167));
  });

  test('imperial depth rounds in feet and still holds the clicked dive', () {
    final o = options(
      DiveField.maxDepth,
      base.copyWith(maxDepth: 23.4167),
      units: imperial,
      prefs: feetPrefs,
    );
    final (lo, hi) = betweenOf(o.first.rule);
    expect(lo, lessThanOrEqualTo(23.4167));
    expect(hi, greaterThanOrEqualTo(23.4167));
    // 76.8 ft plus or minus 0.05 ft, stored in metres.
    expect(hi - lo, closeTo(0.1 * 0.3048, 1e-9));
    final atLeast = (o[1].rule as ConditionNode).value! as NumberValue;
    expect(atLeast.value, lessThanOrEqualTo(23.4167));
    final atMost = (o[2].rule as ConditionNode).value! as NumberValue;
    expect(atMost.value, greaterThanOrEqualTo(23.4167));
  });

  test('durations use whole minutes', () {
    final o = options(
      DiveField.bottomTime,
      base.copyWith(bottomTime: const Duration(minutes: 47, seconds: 50)),
    );
    expect((o.first.rule as ConditionNode).value, const NumberValue(47, null));
  });

  test('surface interval reads the computed map', () {
    final o = options(
      DiveField.surfaceInterval,
      base,
      si: const {'d': Duration(minutes: 65)},
    );
    expect((o.first.rule as ConditionNode).value, const NumberValue(65, null));
  });

  test('a date offers Only, On or after, On or before by day', () {
    final o = options(
      DiveField.dateTime,
      base.copyWith(entryTime: DateTime.utc(2026, 4, 1, 9)),
    );
    expect(o.map((x) => x.kind), [
      CellFilterKind.only,
      CellFilterKind.onOrAfter,
      CellFilterKind.onOrBefore,
    ]);
    expect(
      (o.first.rule as ConditionNode).value,
      DateValue(DateTime.utc(2026, 4, 1)),
    );
  });

  test('tags offer With and Without per tag', () {
    final at = DateTime.utc(2026, 1, 1);
    final o = options(
      DiveField.tags,
      base.copyWith(
        tags: [
          Tag(id: 't1', name: 'Night', createdAt: at, updatedAt: at),
          Tag(id: 't2', name: 'Wreck', createdAt: at, updatedAt: at),
        ],
      ),
    );
    expect(o.map((x) => x.kind), [
      CellFilterKind.withValue,
      CellFilterKind.withoutValue,
      CellFilterKind.withValue,
      CellFilterKind.withoutValue,
    ]);
    expect(o[2].valueLabel, 'Wreck');
  });

  test('an enum offers Only and Exclude by name', () {
    final o = options(
      DiveField.diveMode,
      base.copyWith(diveMode: enums.DiveMode.ccr),
    );
    expect(
      (o.first.rule as ConditionNode).value,
      isA<EnumValue>().having((v) => v.name, 'name', 'ccr'),
    );
  });

  group('derived display offers no items', () {
    test('runtime derived from timestamps', () {
      final d = base.copyWith(
        entryTime: DateTime.utc(2026, 4, 1, 9),
        exitTime: DateTime.utc(2026, 4, 1, 9, 50),
      );
      expect(options(DiveField.runtime, d), isEmpty);
    });

    test('entry method inherited from the site', () {
      final d = base.copyWith(
        site: const DiveSite(
          id: 's',
          name: 'S',
          entryMethod: enums.EntryMethod.shore,
        ),
      );
      expect(options(DiveField.entryMethod, d), isEmpty);
    });

    test('legacy free-text buddy', () {
      expect(options(DiveField.buddy, base.copyWith(buddy: 'Sam')), isEmpty);
    });

    test('legacy visibility bucket', () {
      expect(
        options(
          DiveField.visibility,
          base.copyWith(visibility: enums.Visibility.good),
        ),
        isEmpty,
      );
    });

    test('a dive name shown from its site', () {
      expect(
        options(
          DiveField.diveName,
          base.copyWith(
            site: const DiveSite(id: 's', name: 'S'),
          ),
        ),
        isEmpty,
      );
    });
  });

  test('header-only and unfilterable columns offer nothing', () {
    expect(options(DiveField.notes, base.copyWith(notes: 'x')), isEmpty);
    expect(options(DiveField.altitude, base.copyWith(altitude: 300)), isEmpty);
  });
}
