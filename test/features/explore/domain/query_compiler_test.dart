import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/domain/unit_grounding.dart';

void main() {
  const metric = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );
  const imperial = (
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
  );
  final now = DateTime(2026, 9, 19);

  const names = NameIndex([
    NameEntry(
      kind: MentionKind.place,
      label: 'Bonaire',
      ids: ['s1', 's2'],
      target: NameTarget.sitePlace,
    ),
    NameEntry(
      kind: MentionKind.species,
      label: 'Green Turtle',
      ids: ['sp_green_turtle'],
      target: NameTarget.speciesId,
    ),
    NameEntry(
      kind: MentionKind.species,
      label: 'Hawksbill Turtle',
      ids: ['sp_hawksbill_turtle'],
      target: NameTarget.speciesId,
    ),
    NameEntry(
      kind: MentionKind.gear,
      label: 'Trilaminate',
      ids: [],
      target: NameTarget.attrChoice,
      rank: 2,
      attrKey: 'shell_material',
      attrChoice: 'trilaminate',
    ),
    NameEntry(
      kind: MentionKind.buddy,
      label: 'Sarah Jones',
      ids: ['b1'],
      target: NameTarget.buddyId,
    ),
  ]);

  CompiledQuery compile(ParsedQuery q, {UnitPrefs units = metric}) =>
      QueryCompiler.compile(
        q,
        CompilerContext(units: units, names: names, now: now),
      );

  ParsedQuery turtlesQuery() => ParsedQuery.fromJson({
    'schemaVersion': 1,
    'subject': 'dives',
    'clauses': [
      {
        'field': 'depth',
        'op': 'gt',
        'value': 20,
        'unit': 'm',
        'text': 'below 20m',
      },
      {
        'field': 'visibility',
        'op': 'gt',
        'value': 20,
        'unit': 'm',
        'text': 'viz over 20m',
      },
    ],
    'mentions': [
      {'kind': 'species', 'text': 'green turtle'},
      {'kind': 'place', 'text': 'Bonaire'},
    ],
    'unplaced': <String>[],
  });

  test('a strict operator lowers to the inclusive bound it will apply', () {
    final c = compile(turtlesQuery());
    // The filter axis is `>= 20`, so a 20 m dive matches; the chip must not
    // claim the query was strict.
    expect(c.filter.minDepth, 20);
    expect((c.chips.first.payload as ClauseChip).op, ClauseOp.gte);
  });

  test(
    'the turtles sentence compiles to depth, visibility, species and sites',
    () {
      final c = compile(turtlesQuery());
      expect(c.filter.minDepth, 20);
      expect(c.filter.minVisibility, 20);
      expect(c.filter.speciesIds, ['sp_green_turtle']);
      expect(c.filter.siteIds, ['s1', 's2']);
      expect(c.filter.siteId, isNull);
      expect(c.chips, hasLength(4));
      expect(c.unresolved, isEmpty);
      expect(c.unplaced, isEmpty);
      expect(c.charts.map((x) => x.kind), [
        ChartKind.divesOverTime,
        ChartKind.depthTrend,
        ChartKind.entityCounts,
      ]);
      expect(c.charts.last.entityKind, MentionKind.place);
    },
  );

  test(
    'a bare number takes the diver unit and the chip keeps the metric value',
    () {
      final q = ParsedQuery.fromJson({
        'schemaVersion': 1,
        'subject': 'dives',
        'clauses': [
          {
            'field': 'depth',
            'op': 'lt',
            'value': 60,
            'text': 'shallower than 60',
          },
          {
            'field': 'waterTemp',
            'op': 'lt',
            'value': 60,
            'text': 'colder than 60',
          },
        ],
      });
      final c = compile(q, units: imperial);
      expect(c.filter.maxDepth, closeTo(18.29, 0.01));
      expect(c.filter.maxWaterTemp, closeTo(15.56, 0.01));
      final chip = c.chips.first.payload as ClauseChip;
      expect(chip.field, ExploreDiveField.depth);
      // The bound is inclusive, so the chip says so rather than repeating
      // the model's strict "shallower than".
      expect(chip.op, ClauseOp.lte);
      expect(chip.value, closeTo(18.29, 0.01));
      expect(chip.dimension, FieldDimension.depth);
    },
  );

  test('between, water types, flags, weekdays and time lower correctly', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'dives',
      'clauses': [
        {
          'field': 'depth',
          'op': 'between',
          'value': [30, 10],
          'unit': 'm',
          'text': '10 to 30m',
        },
        {
          'field': 'waterType',
          'op': 'not',
          'value': 'salt',
          'text': 'not in the sea',
        },
        {'field': 'favorite', 'op': 'eq', 'value': true, 'text': 'favourite'},
        {'field': 'deco', 'op': 'eq', 'value': false, 'text': 'no deco'},
        {
          'field': 'weekday',
          'op': 'in',
          'value': ['sat', 'sun'],
          'text': 'weekends',
        },
        {
          'field': 'bottomTime',
          'op': 'gte',
          'value': 45,
          'text': 'over 45 minutes',
        },
      ],
      'time': {'text': 'last year'},
    });
    final c = compile(q);
    expect(c.filter.minDepth, 10);
    expect(c.filter.maxDepth, 30);
    expect(c.filter.waterTypes, [WaterType.fresh, WaterType.brackish]);
    expect(c.filter.favoritesOnly, isTrue);
    expect(c.filter.decoOnly, isFalse);
    expect(c.filter.weekdays, [6, 7]);
    expect(c.filter.minBottomTimeMinutes, 45);
    expect(c.filter.startDate, DateTime(2025, 1, 1));
    expect(c.filter.endDate, DateTime(2025, 12, 31));
    expect(c.chips.where((x) => x.ref == ChipRef.time), hasLength(1));
    expect(c.unplaced, isEmpty);
  });

  test('favorite eq false has no axis and is unplaced', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'dives',
      'clauses': [
        {
          'field': 'favorite',
          'op': 'eq',
          'value': 'false',
          'text': 'not favourite',
        },
      ],
    });
    final c = compile(q);
    expect(c.filter.favoritesOnly, isNull);
    expect(c.unplaced.single.text, 'not favourite');
  });

  test('gear attribute mentions become attribute conditions', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'dives',
      'mentions': [
        {'kind': 'gear', 'text': 'trilaminate'},
        {'kind': 'buddy', 'text': 'Sarah Jones'},
      ],
    });
    final c = compile(q);
    expect(c.filter.equipmentAttrConditions.single.key, 'shell_material');
    expect(c.filter.equipmentAttrConditions.single.choices, {'trilaminate'});
    expect(c.filter.buddyId, 'b1');
  });

  test('unknown fields, bad ops, out-of-range values and unknown time are '
      'unplaced with reasons', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'dives',
      'clauses': [
        {'field': 'salinity', 'op': 'gt', 'value': 3, 'text': 'salty'},
        {
          'field': 'depth',
          'op': 'in',
          'value': [1, 2],
          'text': 'depth in',
        },
        {
          'field': 'depth',
          'op': 'gt',
          'value': 900,
          'unit': 'm',
          'text': 'below 900m',
        },
        {'field': 'waterTemp', 'op': 'gt', 'value': 'warm', 'text': 'warm'},
        {'field': 'avgDepth', 'op': 'gt', 'value': 10, 'text': 'avg over 10'},
      ],
      'time': {'text': 'when the water was warm'},
      'unplaced': ['maybe'],
    });
    final c = compile(q);
    expect(c.filter.hasActiveFilters, isFalse);
    expect(c.unplaced.map((u) => u.text), [
      'salty',
      'depth in',
      'below 900m',
      'warm',
      'avg over 10',
      'when the water was warm',
      'maybe',
    ]);
    expect(c.unplaced.map((u) => u.reason), [
      'unknownField',
      'invalid',
      'outOfRange',
      'invalid',
      'noAxis',
      'unknownTime',
      null,
    ]);
  });

  test('an unresolved mention carries candidates and lowers nothing', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'dives',
      'mentions': [
        {'kind': 'species', 'text': 'turtles'},
      ],
    });
    final c = compile(q);
    expect(c.filter.speciesIds, isEmpty);
    expect(c.unresolved.single.mention.text, 'turtles');
    expect(
      c.unresolved.single.candidates.map((e) => e.label),
      containsAll(['Green Turtle', 'Hawksbill Turtle']),
    );
  });

  test('a non-dive subject is one unplaced item and an empty filter', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 1,
      'subject': 'equipment',
    });
    final c = compile(q);
    expect(c.filter.hasActiveFilters, isFalse);
    expect(c.unplaced.single.reason, 'subjectNotSupported');
  });
}
