import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  final now = DateTime(2026, 9, 19);
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );

  CompiledQuery compile(List<Map<String, Object?>> clauses) =>
      QueryCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': clauses,
        }),
        CompilerContext(units: units, names: const NameIndex([]), now: now),
      );

  test('the schema version is 2 now that the derived fields exist', () {
    expect(kQuerySchemaVersion, 2);
  });

  test('the askable finding names stay in step with the engine', () {
    // safetyFindingNames is spelled out because it sits in a const map, so
    // a new rule would otherwise be silently unaskable.
    expect(safetyFindingNames, SafetyRuleId.values.map((r) => r.name).toList());
  });

  test('the prompt lists every field the catalog accepts', () {
    final text = NlPrompt.instructions();
    for (final name in DiveFieldCatalog.jsonNames) {
      expect(text, contains('$name:'), reason: name);
    }
    expect(text, contains('"schemaVersion":$kQuerySchemaVersion'));
  });

  test('a SAC trend lowers to a trend predicate', () {
    final c = compile([
      {'field': 'sacTrend', 'op': 'eq', 'value': 'rising', 'text': 'SAC rose'},
    ]);
    expect(c.filter.derivedPredicates, [const SacTrendIs(SacTrend.rising)]);
    expect(c.unplaced, isEmpty);
    expect(c.chips, hasLength(1));
  });

  test('SAC rising after N minutes lowers with the minutes', () {
    final c = compile([
      {
        'field': 'sacRoseAfter',
        'op': 'eq',
        'value': 20,
        'unit': 'min',
        'text': 'SAC increased after 20 minutes',
      },
    ]);
    expect(c.filter.derivedPredicates, [const SacRoseAfter(minutes: 20)]);
  });

  test('an unstable final stop lowers to the default threshold', () {
    final c = compile([
      {
        'field': 'finalStopUnstable',
        'op': 'eq',
        'value': true,
        'text': 'the final stop was unstable',
      },
    ]);
    expect(c.filter.derivedPredicates, [const FinalStopUnstable()]);
  });

  test('a stable final stop is not a filter we can express', () {
    // "the final stop was stable" is the negation of an EXISTS, which the
    // axis does not carry. It must be unplaced rather than silently
    // becoming its opposite.
    final c = compile([
      {
        'field': 'finalStopUnstable',
        'op': 'eq',
        'value': false,
        'text': 'the final stop was stable',
      },
    ]);
    expect(c.filter.derivedPredicates, isEmpty);
    expect(c.unplaced, hasLength(1));
  });

  test('a final stop duration converts minutes to seconds', () {
    final c = compile([
      {
        'field': 'finalStopDuration',
        'op': 'gte',
        'value': 3,
        'unit': 'min',
        'text': 'a stop of at least three minutes',
      },
    ]);
    expect(c.filter.derivedPredicates, [
      const FinalStopDuration(minSeconds: 180),
    ]);
  });

  test('a final stop duration range binds both bounds', () {
    final c = compile([
      {
        'field': 'finalStopDuration',
        'op': 'between',
        'value': [3, 5],
        'unit': 'min',
        'text': 'a stop of three to five minutes',
      },
    ]);
    expect(c.filter.derivedPredicates, [
      const FinalStopDuration(minSeconds: 180, maxSeconds: 300),
    ]);
  });

  test('a list of findings becomes one predicate each', () {
    final c = compile([
      {
        'field': 'safetyFinding',
        'op': 'in',
        'value': ['rapidAscent', 'omittedSafetyStop'],
        'text': 'ascent or safety stop problems',
      },
    ]);
    expect(c.filter.derivedPredicates, [
      const HasFinding(SafetyRuleId.rapidAscent),
      const HasFinding(SafetyRuleId.omittedSafetyStop),
    ]);
  });

  test('an unknown trend or rule is unplaced, not guessed', () {
    final c = compile([
      {'field': 'sacTrend', 'op': 'eq', 'value': 'wobbly', 'text': 'a'},
      {'field': 'safetyFinding', 'op': 'eq', 'value': 'kraken', 'text': 'b'},
    ]);
    expect(c.filter.derivedPredicates, isEmpty);
    expect(c.unplaced.map((u) => u.reason), ['invalid', 'invalid']);
  });

  test('the sentence from the spec compiles end to end', () {
    final c = compile([
      {
        'field': 'waterTemp',
        'op': 'lt',
        'value': 15,
        'unit': 'c',
        'text': 'cold-water',
      },
      {
        'field': 'sacRoseAfter',
        'op': 'eq',
        'value': 20,
        'unit': 'min',
        'text': 'SAC increased after 20 minutes',
      },
      {
        'field': 'finalStopUnstable',
        'op': 'eq',
        'value': true,
        'text': 'the final stop was unstable',
      },
    ]);
    expect(c.filter.maxWaterTemp, 15);
    expect(c.filter.derivedPredicates, [
      const SacRoseAfter(minutes: 20),
      const FinalStopUnstable(),
    ]);
    expect(c.unplaced, isEmpty);
    expect(c.chips, hasLength(3));
    expect(c.filter.readsDerivedMetrics, isTrue);
  });
}
