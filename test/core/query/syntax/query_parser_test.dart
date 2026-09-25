import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final now = DateTime(2026, 9, 25);
  const names = MapNameResolver({
    QuerySubject.sites: {
      'Salt Pier': 'site-1',
      'Salt Pier Deep': 'site-2',
      'Hilma Hooker': 'site-3',
    },
  });
  QueryParser metric() => QueryParser(
    fixtureRegistry,
    fixtureDives,
    ParseContext(prefs: kMetricPrefs, now: now, names: names),
  );
  QueryParser imperial() => QueryParser(
    fixtureRegistry,
    fixtureDives,
    ParseContext(
      prefs: const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
      now: now,
      names: names,
    ),
  );

  QueryNode ok(QueryParser p, String s) {
    final r = p.parse(s);
    expect(r, isA<ParseOk>(), reason: '$r');
    return (r as ParseOk).node!;
  }

  ParseFailure bad(QueryParser p, String s) {
    final r = p.parse(s);
    expect(
      r,
      isA<ParseFailure>(),
      reason: 'parsed $s as ${r is ParseOk ? r.node : r}',
    );
    return r as ParseFailure;
  }

  test('empty text is an empty query', () {
    expect((metric().parse('   ') as ParseOk).node, isNull);
  });

  test(
    'numbers ground to storage: bare in the preference, suffix explicit',
    () {
      expect(
        ok(metric(), 'depth > 30'),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
      );
      final imp = ok(imperial(), 'depth > 100') as ConditionNode;
      expect((imp.value as NumberValue).value, closeTo(30.48, 0.001));
      final ft = ok(metric(), 'depth > 100ft') as ConditionNode;
      expect((ft.value as NumberValue).typedUnit, QueryUnit.ft);
      expect((ft.value as NumberValue).value, closeTo(30.48, 0.001));
      expect(
        ok(metric(), 'temp < -2'),
        ConditionNode(
          const FieldPath(['waterTemp']),
          QueryOp.lt,
          const NumberValue(-2, null),
        ),
      );
    },
  );

  test('precedence: NOT, then AND (juxtaposition), then OR; parens group', () {
    expect(
      ok(metric(), 'depth > 30 rating >= 4 OR NOT favorite = true'),
      OrNode([
        AndNode([
          ConditionNode(
            const FieldPath(['depth']),
            QueryOp.gt,
            const NumberValue(30, null),
          ),
          ConditionNode(
            const FieldPath(['rating']),
            QueryOp.gte,
            const NumberValue(4, null),
          ),
        ]),
        NotNode(
          ConditionNode(
            const FieldPath(['favorite']),
            QueryOp.eq,
            const BoolValue(true),
          ),
        ),
      ]),
    );
    expect(
      ok(metric(), '(weights:none | temp:none) & rating:any'),
      AndNode([
        OrNode([
          ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
          ConditionNode(const FieldPath(['waterTemp']), QueryOp.isEmpty, null),
        ]),
        ConditionNode(const FieldPath(['rating']), QueryOp.isSet, null),
      ]),
    );
  });

  test('the colon shorthand follows the field type', () {
    expect(
      ok(metric(), 'waterType:salt'),
      ConditionNode(
        const FieldPath(['waterType']),
        QueryOp.eq,
        const EnumValue('salt'),
      ),
    );
    expect(
      ok(metric(), 'notes:manta'),
      ConditionNode(
        const FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('manta'),
      ),
    );
    expect(
      ok(metric(), 'depth:30'),
      ConditionNode(
        const FieldPath(['depth']),
        QueryOp.eq,
        const NumberValue(30, null),
      ),
    );
  });

  test('lists, between, contains and negation', () {
    expect(
      ok(metric(), 'waterType in [salt, Fresh]'),
      ConditionNode(
        const FieldPath(['waterType']),
        QueryOp.inList,
        const ListValue([EnumValue('salt'), EnumValue('fresh')]),
      ),
    );
    expect(
      ok(metric(), 'depth between 18 and 30'),
      ConditionNode(
        const FieldPath(['depth']),
        QueryOp.between,
        const ListValue([NumberValue(18, null), NumberValue(30, null)]),
      ),
    );
    expect(
      ok(metric(), 'notes ~ "night dive"'),
      ConditionNode(
        const FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('night dive'),
      ),
    );
    expect(
      ok(metric(), '-favorite = true'),
      NotNode(
        ConditionNode(
          const FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        ),
      ),
    );
  });

  test('dates: a day, a year, a month, quoted phrases, open ranges', () {
    expect(
      ok(metric(), 'date >= 2025-01-15'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.gte,
        DateValue(DateTime(2025, 1, 15)),
      ),
    );
    expect(
      ok(metric(), 'date in 2025'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2025, 1, 1), DateTime(2025, 12, 31)),
      ),
    );
    expect(
      ok(metric(), 'date = 2025-03'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2025, 3, 1), DateTime(2025, 3, 31)),
      ),
    );
    expect(
      ok(metric(), 'date in "last 90 days"'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.inList,
        DateRangeValue(DateTime(2026, 6, 27), DateTime(2026, 9, 25)),
      ),
    );
    expect(
      ok(metric(), 'date between 2025-03-14 and 2025-03-15'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.between,
        ListValue([
          DateValue(DateTime(2025, 3, 14)),
          DateValue(DateTime(2025, 3, 15)),
        ]),
      ),
    );
    expect(
      bad(metric(), 'date between 2025 and 2026').error.message,
      contains('single day'),
    );
    expect(
      ok(metric(), 'date in "since 2024"'),
      ConditionNode(
        const FieldPath(['date']),
        QueryOp.gte,
        DateValue(DateTime(2024, 1, 1)),
      ),
    );
  });

  test('refs resolve by name and report candidates when they do not', () {
    expect(
      ok(metric(), 'site = "Salt Pier"'),
      ConditionNode(const FieldPath(['site']), QueryOp.eq, kFixtureSite),
    );
    final f = bad(metric(), 'site = "Salt Peer"');
    expect(f.error.suggestions, contains('Salt Pier'));
    expect(f.error.offset, 7);
  });

  test('paths, scoped groups and bare text', () {
    expect(
      ok(metric(), 'site.country = Mexico'),
      ConditionNode(
        const FieldPath(['site', 'country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
    );
    expect(
      ok(metric(), 'buddies.certifications.level = rescue'),
      ConditionNode(
        const FieldPath(['buddies', 'certifications', 'level']),
        QueryOp.eq,
        const StringValue('rescue'),
      ),
    );
    expect(
      ok(metric(), 'gear[type in [wetsuit, drysuit]]'),
      ScopedNode(
        const FieldPath(['gear']),
        ConditionNode(
          const FieldPath(['type']),
          QueryOp.inList,
          const ListValue([EnumValue('wetsuit'), EnumValue('drysuit')]),
        ),
      ),
    );
    expect(
      ok(metric(), '"night dive" manta'),
      const AndNode([
        TextNode(['night', 'dive']),
        TextNode(['manta']),
      ]),
    );
    expect(ok(metric(), 'depth'), const TextNode(['depth']));
  });

  test('positioned errors', () {
    expect(bad(metric(), 'depht > 30').error.suggestions, contains('depth'));
    expect(bad(metric(), 'depht > 30').error.offset, 0);
    expect(bad(metric(), 'depth > 18,5').error.message, contains(','));
    expect(bad(metric(), 'depth > 18,5').error.offset, 10);
    expect(bad(metric(), 'waterType in []').error.message, contains('empty'));
    expect(bad(metric(), 'rating > 3m').error.message, contains('unit'));
    expect(bad(metric(), 'depth > 30xx').error.message, contains('unit'));
    expect(
      bad(metric(), 'waterType = lake').error.suggestions,
      contains('salt'),
    );
    expect(bad(metric(), 'favorite ~ x').error.message, contains('~'));
    expect(bad(metric(), '(depth > 30').error.message, contains(')'));
    expect(bad(metric(), 'depth > ').error.message, contains('value'));
    expect(
      bad(metric(), 'weights = 3').error.message,
      contains('no weights named'),
    );
    expect(bad(metric(), 'weights > 3').error.message, contains('relation'));
  });
}
