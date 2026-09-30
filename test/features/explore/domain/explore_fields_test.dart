import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

const _imperial = UnitPrefs(
  depth: DepthUnit.feet,
  temperature: TemperatureUnit.fahrenheit,
  pressure: PressureUnit.psi,
  weight: WeightUnit.pounds,
  volume: VolumeUnit.cubicFeet,
);

void main() {
  test('the model keeps every field name it had', () {
    expect(kExploreFields.map((f) => f.name), [
      'depth',
      'avgDepth',
      'bottomTime',
      'waterTemp',
      'airTemp',
      'visibility',
      'rating',
      'o2',
      'diveNumber',
      'waterType',
      'diveMode',
      'entryMethod',
      'currentStrength',
      'favorite',
      'deco',
      'noBuddy',
      'weekday',
      'diveType',
      'sac',
      'sacTrend',
      'sacChange',
      'finalStop',
      'finalStopExcursion',
      'finalStopDuration',
      'finding',
    ]);
  });

  test('every number and enum field resolves on the dive registry', () {
    for (final f in kExploreFields) {
      if (f.kind == ExploreValueKind.flag && f.name == 'noBuddy') continue;
      expect(f.field, isNotNull, reason: f.name);
    }
  });

  test('dimensions and enum values come from the registry', () {
    expect(exploreField('depth')!.dimension, FieldDimension.depth);
    expect(exploreField('sac')!.dimension, FieldDimension.pressureRate);
    expect(exploreField('o2')!.dimension, FieldDimension.percent);
    expect(
      exploreField('waterType')!.enumValues,
      diveQueryEntity.field('waterType')!.enumValues,
    );
    expect(exploreField('weekday')!.enumValues, kWeekdayTokens);
  });

  test(
    'bounds: the registry sanity first, Explore\'s own where it has none',
    () {
      expect(exploreField('depth')!.accepts(401), isFalse);
      expect(exploreField('visibility')!.accepts(201), isFalse);
      expect(exploreField('o2')!.accepts(0.5), isFalse);
      expect(exploreField('bottomTime')!.accepts(1441), isFalse);
      expect(exploreField('diveNumber')!.accepts(-1), isFalse);
    },
  );

  test('ops follow the value kind', () {
    expect(exploreField('depth')!.ops, contains(ClauseOp.between));
    expect(exploreField('waterType')!.ops, {
      ClauseOp.eq,
      ClauseOp.inList,
      ClauseOp.not,
    });
    expect(exploreField('favorite')!.ops, {ClauseOp.eq});
    expect(exploreField('diveType')!.ops, {ClauseOp.eq, ClauseOp.inList});
  });

  test('o2 and finding reach through a relation', () {
    expect(exploreField('o2')!.path, ['tanks', 'o2']);
    expect(exploreField('finding')!.path, ['findings', 'rule']);
    expect(
      FieldPath(exploreField('diveType')!.path),
      FieldPath(['types', 'name']),
    );
  });

  test('clause units map to query units for the field they are said on', () {
    expect(queryUnitOf(ClauseUnit.ft, FieldDimension.depth), QueryUnit.ft);
    // Divers drop "per minute": a plain bar or psi on a rate is a rate.
    expect(
      queryUnitOf(ClauseUnit.bar, FieldDimension.pressureRate),
      QueryUnit.barMin,
    );
    expect(
      queryUnitOf(ClauseUnit.psi, FieldDimension.pressureRate),
      QueryUnit.psiMin,
    );
    expect(
      queryUnitOf(ClauseUnit.barMin, FieldDimension.pressureRate),
      QueryUnit.barMin,
    );
    expect(queryUnitOf(ClauseUnit.lMin, FieldDimension.pressureRate), isNull);
    expect(queryUnitOf(null, FieldDimension.depth), isNull);
  });

  test('an explicit unit wins over the diver preference', () {
    expect(groundClause(20, ClauseUnit.m, FieldDimension.depth, _imperial), 20);
    expect(
      groundClause(66, ClauseUnit.ft, FieldDimension.depth, kMetricPrefs),
      closeTo(20.1, 0.05),
    );
    expect(
      groundClause(50, ClauseUnit.f, FieldDimension.temperature, kMetricPrefs),
      closeTo(10, 1e-9),
    );
    expect(
      groundClause(3000, ClauseUnit.psi, FieldDimension.pressure, kMetricPrefs),
      closeTo(206.8, 0.1),
    );
  });

  test('a bare number takes the diver preference for the dimension', () {
    expect(groundClause(20, null, FieldDimension.depth, kMetricPrefs), 20);
    expect(
      groundClause(20, null, FieldDimension.depth, _imperial),
      closeTo(6.1, 0.01),
    );
    expect(
      groundClause(60, null, FieldDimension.temperature, _imperial),
      closeTo(15.56, 0.01),
    );
  });

  test('dimensionless fields ignore any unit', () {
    expect(
      groundClause(4, ClauseUnit.m, FieldDimension.count, kMetricPrefs),
      4,
    );
    expect(
      groundClause(45, ClauseUnit.f, FieldDimension.minutes, _imperial),
      45,
    );
    expect(groundClause(32, null, FieldDimension.percent, _imperial), 32);
  });

  test('a unit fits only a field measured in its kind', () {
    expect(unitFits(FieldDimension.depth, ClauseUnit.ft), isTrue);
    expect(unitFits(FieldDimension.depth, ClauseUnit.c), isFalse);
    expect(unitFits(FieldDimension.temperature, ClauseUnit.m), isFalse);
    expect(unitFits(FieldDimension.pressure, ClauseUnit.min), isFalse);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.bar), isTrue);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.psiMin), isTrue);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.lMin), isFalse);
    expect(unitFits(FieldDimension.minutes, ClauseUnit.bar), isFalse);
    expect(unitFits(FieldDimension.depth, null), isTrue);
    expect(unitFits(FieldDimension.count, ClauseUnit.m), isTrue);
    expect(unitFits(FieldDimension.none, ClauseUnit.c), isTrue);
    // The model has no weight or volume unit, so any unit said on such a
    // field is of another kind; a bare number still takes the diver's unit.
    expect(unitFits(FieldDimension.weight, ClauseUnit.m), isFalse);
    expect(unitFits(FieldDimension.volume, ClauseUnit.bar), isFalse);
    expect(unitFits(FieldDimension.weight, null), isTrue);
  });

  test('a SAC unit said without per minute is per minute', () {
    expect(rateUnitSaid(ClauseUnit.bar, _imperial), PressureUnit.bar);
    expect(rateUnitSaid(ClauseUnit.psiMin, kMetricPrefs), PressureUnit.psi);
    expect(rateUnitSaid(null, _imperial), PressureUnit.psi);
    expect(
      groundClause(1.5, ClauseUnit.bar, FieldDimension.pressureRate, _imperial),
      closeTo(1.5, 1e-9),
    );
  });

  test('each trend chart is drawn for exactly one numeric field', () {
    expect(
      {
        for (final f in kExploreFields)
          if (f.trend != null) f.name: f.trend,
      },
      {
        'depth': ChartKind.depthTrend,
        'waterTemp': ChartKind.waterTempTrend,
        'bottomTime': ChartKind.bottomTimeTrend,
        'sac': ChartKind.sacTrend,
      },
    );
    for (final f in kExploreFields.where((f) => f.trend != null)) {
      expect(f.kind, ExploreValueKind.number, reason: f.name);
      expect(f.trend!.isTrend, isTrue, reason: f.name);
    }
  });

  test('only a flag has a label for its off value', () {
    for (final f in kExploreFields.where((f) => f.offLabelKey != null)) {
      expect(f.kind, ExploreValueKind.flag, reason: f.name);
    }
    expect(exploreField('deco')!.offLabelKey, 'explore_chip_noDeco');
  });

  test('an unknown name is null', () => expect(exploreField('nope'), isNull));
}
