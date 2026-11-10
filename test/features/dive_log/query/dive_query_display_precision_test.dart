import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// Issue #4398: a typed number compares with the value as the app shows it,
/// rounded, not with the unrounded stored value. A dive stored at 8.26 m is
/// listed as 27.1 ft, so `depth < 27.1` must not find it.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    // Shown in feet to one decimal: d1 27.1, d2 27.0, d3 27.2; d5 stays
    // at 40 m (131.2 ft).
    await db.customStatement(
      "UPDATE dives SET max_depth = 8.26 WHERE id = 'd1'",
    );
    await db.customStatement(
      "UPDATE dives SET max_depth = 8.23 WHERE id = 'd2'",
    );
    await db.customStatement(
      "UPDATE dives SET max_depth = 8.29 WHERE id = 'd3'",
    );
    // Shown in pounds to one decimal: d2 12.0 (12.015 lb, the legacy
    // scalar), d5 12.1 (its weight row); d1 keeps 2 kg (4.4 lb).
    await db.customStatement(
      "UPDATE dives SET weight_amount = 5.45 WHERE id = 'd2'",
    );
    await db.customStatement(
      "UPDATE dive_weights SET amount_kg = 5.5 WHERE id = 'w5'",
    );
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  Future<Set<String>> run(QueryNode? node) async {
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND ${q.where}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> ids(String text, {UnitPrefs prefs = imperial}) {
    final parser = QueryParser(
      appQueryRegistry,
      dives,
      ParseContext(
        prefs: prefs,
        now: DateTime(2026, 11, 9),
        names: const MapNameResolver({}),
      ),
    );
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    return run((parsed as ParseOk).node);
  }

  /// A plain-word Explore clause ("deeper than 27.1 ft"), as the model
  /// hands it over, lowered and run the same way.
  Future<Set<String>> explore(
    String field,
    String op,
    Object value, {
    String? unit,
  }) {
    final compiled = ExploreCompiler.compile(
      ParsedQuery.fromJson({
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
        'clauses': [
          {
            'field': field,
            'op': op,
            'value': value,
            'unit': ?unit,
            'text': field,
          },
        ],
      }),
      ExploreCompilerContext(
        units: imperial,
        names: NameIndex.empty,
        now: DateTime(2026, 11, 9),
      ),
    );
    expect(compiled.unplaced, isEmpty);
    return run(compiled.query);
  }

  test('strict bounds leave out a dive shown at the bound', () async {
    expect(await ids('depth < 27.1'), {'d2'}, reason: 'd1 shows 27.1 ft');
    expect(await ids('depth > 27.1'), {'d3', 'd5'});
    expect(await ids('weight > 12'), {'d5'}, reason: 'd2 shows 12.0 lb');
    expect(await ids('weight < 12.1'), {'d1', 'd2'});
  });

  test('inclusive bounds keep a dive shown at the bound', () async {
    expect(await ids('depth <= 27.1'), {'d1', 'd2'});
    expect(await ids('depth >= 27.1'), {'d1', 'd3', 'd5'});
    expect(await ids('weight >= 12'), {'d2', 'd5'});
    expect(await ids('weight <= 12'), {'d1', 'd2'});
  });

  test('equality finds every dive shown as the number', () async {
    expect(await ids('depth = 27.1'), {'d1'});
    expect(await ids('weight = 12'), {'d2'});
    expect(await ids('weight = 12lb'), {'d2'});
    expect(await ids('depth != 27.1'), {'d2', 'd3', 'd5'});
    expect(await ids('depth in [27.0, 27.2]'), {'d2', 'd3'});
  });

  test('between keeps both ends as shown', () async {
    expect(await ids('depth between 27.1 and 27.2'), {'d1', 'd3'});
  });

  test('a number finer than the display compares exactly', () async {
    expect(await ids('depth < 27.15'), {'d1', 'd2'});
    expect(await ids('depth > 27.15'), {'d3', 'd5'});
  });

  test('metric depth reads the same way', () async {
    // d1 at 8.26 m shows 8.3 m; d2 at 8.23 m shows 8.2 m.
    expect(await ids('depth < 8.3', prefs: kMetricPrefs), {'d2'});
    expect(await ids('depth = 8.3', prefs: kMetricPrefs), {'d1', 'd3'});
  });

  group('Explore reads a plain-word number the same way', () {
    test('more and less than are strict, as shown', () async {
      expect(await explore('depth', 'lt', 27.1), {'d2'});
      expect(await explore('depth', 'gt', 27.1), {'d3', 'd5'});
      expect(await explore('depth', 'gt', 27.1, unit: 'ft'), {'d3', 'd5'});
    });

    test('at least and at most take in the value as shown', () async {
      expect(await explore('depth', 'lte', 27.1), {'d1', 'd2'});
      expect(await explore('depth', 'gte', 27.1), {'d1', 'd3', 'd5'});
      expect(await explore('depth', 'between', [27.1, 27.2]), {'d1', 'd3'});
    });

    test('a number finer than the display compares exactly', () async {
      expect(await explore('depth', 'lt', 27.15), {'d1', 'd2'});
    });
  });
}
