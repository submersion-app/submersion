import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/explore_subject_lowering.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Phase 3: a sentence about sites, gear, buddies, species, trips or
/// centers roots at that subject. Its own words stay on it; everything
/// else is about its dives.
void main() {
  final names = NameIndex(const [
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Bonaire',
      ids: ['s1'],
      target: NameTarget.sitePlace,
      placeFields: ['island'],
    ),
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Mexico',
      ids: ['s2'],
      target: NameTarget.sitePlace,
      placeFields: ['country'],
    ),
    NameEntry(
      subject: QuerySubject.species,
      label: 'Turtle',
      ids: ['sp1'],
      target: NameTarget.speciesId,
      primary: true,
    ),
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: ['b1'],
      target: NameTarget.buddyId,
      primary: true,
    ),
  ]);

  ExploreCompilation compile(
    String subject, {
    List<Map<String, Object?>> clauses = const [],
    List<Map<String, Object?>> mentions = const [],
    String? time,
  }) => ExploreCompiler.compile(
    ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': subject,
      'clauses': clauses,
      'mentions': mentions,
      'time': time == null ? null : {'text': time},
      'unplaced': const <String>[],
    }),
    ExploreCompilerContext(
      units: const UnitPrefs(
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
        weight: WeightUnit.kilograms,
        volume: VolumeUnit.liters,
      ),
      names: names,
      now: DateTime(2026, 9, 30),
    ),
  );

  Map<String, Object?> clause(String field, String op, Object value) => {
    'field': field,
    'op': op,
    'value': value,
    'text': '$field $op $value',
  };

  ConditionNode cond(List<String> path, QueryOp op, QueryValue? v) =>
      ConditionNode(FieldPath(path), op, v);

  QueryNode turtles() => cond(
    ['sightings', 'species'],
    QueryOp.inList,
    ListValue([const RefValue('sp1', 'Turtle')]),
  );

  test('sites in Bonaire I have not dived since 2022', () {
    final q = compile(
      'sites',
      clauses: [clause('lastDived', 'lt', '2022')],
      mentions: [
        {'kind': 'place', 'text': 'Bonaire'},
      ],
    );
    expect(q.subject, ParsedSubject.sites);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(['lastDived'], QueryOp.lt, DateValue(DateTime(2022))),
        cond(['island'], QueryOp.eq, const StringValue('Bonaire')),
      ]),
    );
    expect(q.diveScope, isNull);
    expect(q.chips.every((c) => !c.viaDives), isTrue);
    expect(q.charts, [const ChartRequest(ChartKind.subjectCounts)]);
  });

  test('sites where I saw turtles reach the sightings through the dives', () {
    final q = compile(
      'sites',
      mentions: [
        {'kind': 'species', 'text': 'Turtle'},
      ],
    );
    expect(q.query, countedDives([turtles()]));
    expect(q.diveScope, turtles());
    expect(q.chips.single.viaDives, isTrue);
  });

  test('regulators due for service in 30 days', () {
    final q = compile(
      'equipment',
      clauses: [
        clause('gearType', 'eq', 'regulator'),
        clause('serviceDueWithin', 'lte', 30),
      ],
    );
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(
          ['type'],
          QueryOp.inList,
          ListValue(const [EnumValue('regulator')]),
        ),
        cond(
          ['nextServiceDue'],
          QueryOp.lte,
          DateValue(DateTime(2026, 10, 30)),
        ),
      ]),
    );
  });

  test('who have I dived with most this year: the period is the dives', () {
    final q = compile('buddies', time: 'this year');
    final period = [
      cond(['date'], QueryOp.gte, DateValue(DateTime(2026))),
      cond(['date'], QueryOp.lte, DateValue(DateTime(2026, 12, 31))),
    ];
    expect(q.query, countedDives(period));
    expect(q.diveScope, AndNode(period));
    expect(q.chips.single.ref, ChipRef.time);
    expect(q.chips.single.viaDives, isTrue);
  });

  test('species I have only seen once', () {
    final q = compile('species', clauses: [clause('diveCount', 'eq', 1)]);
    expect(
      q.query,
      AndNode([
        cond(['diveCount'], QueryOp.gte, const NumberValue(1, null)),
        cond(['diveCount'], QueryOp.lte, const NumberValue(1, null)),
      ]),
    );
  });

  test("liveaboard trips in 2024: the period is the trip's own dates", () {
    final q = compile(
      'trips',
      clauses: [clause('tripType', 'eq', 'liveaboard')],
      time: '2024',
    );
    expect(
      q.query,
      AndNode([
        cond(
          ['tripType'],
          QueryOp.inList,
          ListValue(const [EnumValue('liveaboard')]),
        ),
        cond(['startDate'], QueryOp.lte, DateValue(DateTime(2024, 12, 31))),
        cond(['endDate'], QueryOp.gte, DateValue(DateTime(2024))),
      ]),
    );
    expect(q.diveScope, isNull);
    expect(q.chips.last.viaDives, isFalse);
  });

  test('centers in Mexico I have used more than twice', () {
    final q = compile(
      'centers',
      clauses: [clause('diveCount', 'gt', 2)],
      mentions: [
        {'kind': 'place', 'text': 'Mexico'},
      ],
    );
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(['diveCount'], QueryOp.gte, const NumberValue(3, null)),
        OrNode([
          cond(['country'], QueryOp.eq, const StringValue('Mexico')),
          cond(['city'], QueryOp.eq, const StringValue('Mexico')),
          cond(['stateProvince'], QueryOp.eq, const StringValue('Mexico')),
        ]),
      ]),
    );
  });

  test('a count with a period is unplaced, not counted all time', () {
    final q = compile(
      'buddies',
      clauses: [clause('diveCount', 'gt', 10)],
      time: 'this year',
    );
    expect(q.unplaced.single.reason, 'countInPeriod');
    expect(q.chips.single.ref, ChipRef.time);
  });

  test('a dive field under buddies is about the dives', () {
    final q = compile('buddies', clauses: [clause('depth', 'gt', 40)]);
    expect(
      q.query,
      countedDives([
        cond(['depth'], QueryOp.gte, const NumberValue(40, null)),
      ]),
    );
    expect(q.chips.single.viaDives, isTrue);
  });

  test("a buddy named under buddies is that buddy's row", () {
    final q = compile(
      'buddies',
      mentions: [
        {'kind': 'buddy', 'text': 'Ana'},
      ],
    );
    expect(
      q.query,
      cond(['name'], QueryOp.inList, ListValue(const [StringValue('Ana')])),
    );
    expect(q.chips.single.viaDives, isFalse);
  });

  test('a subject alone selects every row', () {
    final q = compile('sites');
    expect(q.query, isNull);
    expect(q.chips, isEmpty);
    expect(q.unplaced, isEmpty);
    expect(q.charts, [const ChartRequest(ChartKind.subjectCounts)]);
  });

  test("another subject's own word is unknown", () {
    final q = compile('buddies', clauses: [clause('gearType', 'eq', 'fins')]);
    expect(q.unplaced.single.reason, 'unknownField');
    expect(q.query, isNull);
  });
}
