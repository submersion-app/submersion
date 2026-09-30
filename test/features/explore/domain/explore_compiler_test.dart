import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import 'explore_query_parts.dart';

void main() {
  const metric = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );
  final now = DateTime(2026, 9, 19);

  final names = NameIndex(const [
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Bonaire',
      ids: ['s1', 's2'],
      target: NameTarget.sitePlace,
    ),
    NameEntry(
      subject: QuerySubject.species,
      label: 'Green Turtle',
      ids: ['sp_green_turtle'],
      target: NameTarget.speciesId,
    ),
    NameEntry(
      subject: QuerySubject.species,
      label: 'Hawksbill Turtle',
      ids: ['sp_hawksbill_turtle'],
      target: NameTarget.speciesId,
    ),
    NameEntry(
      subject: QuerySubject.equipment,
      label: 'Trilaminate',
      ids: [],
      target: NameTarget.attrChoice,
      rank: 2,
      attrKey: 'shell_material',
      attrChoice: 'trilaminate',
    ),
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Sarah Jones',
      ids: ['b1'],
      target: NameTarget.buddyId,
    ),
  ]);

  ExploreCompilation compile(ParsedQuery q, {UnitPrefs units = metric}) =>
      ExploreCompiler.compile(
        q,
        ExploreCompilerContext(units: units, names: names, now: now),
      );

  ParsedQuery turtlesQuery() => ParsedQuery.fromJson({
    'schemaVersion': kQuerySchemaVersion,
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
    expect(boundOf(c, 'depth', QueryOp.gte), 20);
    expect((c.chips.first.payload as ClauseChip).op, ClauseOp.gte);
  });

  test(
    'the turtles sentence compiles to depth, visibility, species and sites',
    () {
      final c = compile(turtlesQuery());
      expect(boundOf(c, 'depth', QueryOp.gte), 20);
      expect(boundOf(c, 'visibility', QueryOp.gte), 20);
      expect(refIdsOf(c, ['sightings', 'species']), ['sp_green_turtle']);
      expect(refIdsOf(c, ['site']), ['s1', 's2']);
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
        'schemaVersion': kQuerySchemaVersion,
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
      expect(boundOf(c, 'depth', QueryOp.lte), closeTo(18.29, 0.01));
      expect(boundOf(c, 'waterTemp', QueryOp.lte), closeTo(15.56, 0.01));
      final chip = c.chips.first.payload as ClauseChip;
      expect(chip.field, exploreField('depth')!);
      // The bound is inclusive, so the chip says so rather than repeating
      // the model's strict "shallower than".
      expect(chip.op, ClauseOp.lte);
      expect(chip.value, closeTo(18.29, 0.01));
      expect(chip.dimension, FieldDimension.depth);
    },
  );

  test('between, water types, flags, weekdays and time lower correctly', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
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
    expect(boundOf(c, 'depth', QueryOp.gte), 10);
    expect(boundOf(c, 'depth', QueryOp.lte), 30);
    // "Not" is a query-tree NOT, which keeps dives with no water type
    // recorded; a complement of the listed values would drop them.
    expect(
      partsOf(c),
      contains(
        NotNode(
          ConditionNode(
            FieldPath(['waterType']),
            QueryOp.inList,
            ListValue(const [EnumValue('salt')]),
          ),
        ),
      ),
    );
    expect(
      partsOf(c),
      containsAll([
        ConditionNode(
          FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        ),
        ConditionNode(FieldPath(['deco']), QueryOp.eq, const BoolValue(false)),
        ConditionNode(
          FieldPath(['weekday']),
          QueryOp.inList,
          ListValue(const [EnumValue('saturday'), EnumValue('sunday')]),
        ),
      ]),
    );
    expect(boundOf(c, 'bottomTime', QueryOp.gte), 45);
    expect(dateBoundOf(c, QueryOp.gte), DateTime(2025, 1, 1));
    expect(dateBoundOf(c, QueryOp.lte), DateTime(2025, 12, 31));
    expect(c.chips.where((x) => x.ref == ChipRef.time), hasLength(1));
    expect(c.unplaced, isEmpty);
  });

  test('favorite eq false has no axis and is unplaced', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
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
    expect(conditionsOf(c, ['favorite'], QueryOp.eq), isEmpty);
    expect(c.unplaced.single.text, 'not favourite');
  });

  test('gear attribute mentions become attribute conditions', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'dives',
      'mentions': [
        {'kind': 'gear', 'text': 'trilaminate'},
        {'kind': 'buddy', 'text': 'Sarah Jones'},
      ],
    });
    final c = compile(q);
    expect(
      partsOf(c),
      contains(
        ScopedNode(
          FieldPath(['gear']),
          equipmentAttrConditionNode(
            const EquipmentAttrCondition(
              key: 'shell_material',
              choices: {'trilaminate'},
            ),
          ),
        ),
      ),
    );
    expect(
      (conditionsOf(c, ['buddies'], QueryOp.eq).single.value! as RefValue).id,
      'b1',
    );
  });

  test('unknown fields, bad ops, out-of-range values and unknown time are '
      'unplaced with reasons', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
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
      ],
      'time': {'text': 'when the water was warm'},
      'unplaced': ['maybe'],
    });
    final c = compile(q);
    expect(c.query, isNull);
    expect(c.unplaced.map((u) => u.text), [
      'salty',
      'depth in',
      'below 900m',
      'warm',
      'when the water was warm',
      'maybe',
    ]);
    expect(c.unplaced.map((u) => u.reason), [
      'unknownField',
      'invalid',
      'outOfRange',
      'invalid',
      'unknownTime',
      null,
    ]);
  });

  test('an unresolved mention carries candidates and lowers nothing', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'dives',
      'mentions': [
        {'kind': 'species', 'text': 'turtles'},
      ],
    });
    final c = compile(q);
    expect(refIdsOf(c, ['sightings', 'species']), isEmpty);
    expect(c.unresolved.single.mention.text, 'turtles');
    expect(
      c.unresolved.single.candidates.map((e) => e.label),
      containsAll(['Green Turtle', 'Hawksbill Turtle']),
    );
  });

  test('a non-dive subject is one unplaced item and an empty filter', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'equipment',
    });
    final c = compile(q);
    expect(c.query, isNull);
    expect(c.unplaced.single.reason, 'subjectNotSupported');
  });
}
