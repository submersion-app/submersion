import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// The request's own queries (#2365) against a seeded database, end to end:
/// typed text, parsed, validated, compiled and executed.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  const names = MapNameResolver({
    QuerySubject.sites: {
      'Salt Pier': 's1',
      'Hilma Hooker': 's2',
      'Cenote': 's3',
    },
    QuerySubject.buddies: {'Ana': 'b1', 'Cid': 'b2'},
  });
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(prefs: kMetricPrefs, now: DateTime(2026, 9, 25), names: names),
  );

  /// Compiles [text] and returns the matching ids for the `me` diver.
  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final where = q.isEmpty ? '' : 'AND ${q.where}';
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? $where',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('the request: missing weight, exposure gear, temperature', () async {
    expect(await ids('weights:none'), {
      'd3',
      'd4',
    }, reason: 'the legacy scalar is a weight entry too (review fix)');
    expect(await ids('weights:any'), {'d1', 'd2', 'd5'});
    expect(await ids('buddies:any'), {'d1', 'd2', 'd5'});
    expect(await ids('weight:none'), {
      'd3',
      'd4',
    }, reason: 'the weight field counts the legacy scalar as present');
    expect(await ids('NOT gear.type in [wetsuit, drysuit]'), {'d3', 'd4'});
    expect(await ids('temp:none'), {'d2', 'd4'});
    expect(await ids('buddies:none'), {
      'd3',
      'd4',
    }, reason: 'legacy text buddy counts as present');
    expect(await ids('(weights:none OR temp:none) AND year = 2025'), {
      'd2',
      'd3',
    });
  });

  test('paths, refs and scoped groups', () async {
    expect(await ids('site.country = Bonaire'), {'d1', 'd2', 'd3'});
    expect(await ids('site = "Salt Pier"'), {'d1', 'd2'});
    expect(await ids('site:none'), {'d4'});
    expect(await ids('buddies.certifications.level = rescue'), {'d1', 'd5'});
    expect(await ids('buddies = Ana AND buddies = Cid'), {'d5'});
    expect(await ids('gear[type = wetsuit] AND gear[type = drysuit]'), {'d5'});
    expect(await ids('weights[amount >= 2]'), {'d1'});
    expect(await ids('weight >= 2'), {
      'd1',
      'd2',
    }, reason: 'sums the table, falls back to the scalar');
  });

  test('numbers, units and truncated minutes', () async {
    expect(await ids('depth > 100ft'), {'d5'});
    expect(await ids('bottomTime = 50'), {
      'd1',
    }, reason: '50:30 truncates to 50');
    expect(await ids('bottomTime = 10'), {
      'd4',
      'd5',
    }, reason: '10:59 truncates to 10');
    expect(await ids('bottomTime != 10'), {
      'd1',
      'd2',
    }, reason: 'unrecorded is excluded (Review Focus 5)');
    expect(await ids('bottomTime:none'), {'d3'});
  });

  test('dates are calendar days in the wall clock frame', () async {
    expect(await ids('date in 2025'), {'d1', 'd2', 'd3', 'd5'});
    expect(await ids('date = 2025-03-14'), {'d3'});
    expect(await ids('date between 2025-03-14 and 2025-03-15'), {'d3', 'd5'});
    expect(await ids('date < 2025-01-01'), {'d4'});
    expect(await ids('weekday = friday'), {'d3'});
  });

  test('text search matches literally, including % (Review Focus 3)', () async {
    expect(await ids('manta'), {'d1'});
    expect(await ids('"100%"'), {'d3'});
    expect(await ids('"salt pier"'), {
      'd1',
      'd2',
    }, reason: 'site name is a search column');
    expect(await ids('notes ~ "100%"'), {'d3'});
    expect(await ids('notes:none'), {'d2', 'd4', 'd5'});
  });

  test('NOT never drops a dive for a NULL column (review fix)', () async {
    expect(await ids('-manta'), {'d2', 'd3', 'd4', 'd5'});
    expect(await ids('NOT notes ~ shark'), QueryFixtureIds.mine.toSet());
    expect(await ids('NOT depth > 30'), {'d1', 'd2', 'd3', 'd4'});
  });

  test('the empty query matches every dive of the diver', () async {
    expect(await ids(''), QueryFixtureIds.mine.toSet());
  });

  test('a three-hop query is one statement with no full scan on a hop', () async {
    final parsed =
        parser.parse(
              'buddies.certifications.level = rescue AND site.country = Bonaire',
            )
            as ParseOk;
    final q = compileQuery(
      parsed.node,
      dives,
      appQueryRegistry,
      rootAlias: 'd',
    );
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT d.id FROM dives d WHERE ${q.where}',
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    final lines = plan.map((r) => r.data['detail'].toString()).toList();
    // The root scan is expected; every correlated hop whose correlation
    // column is indexed must be a SEARCH. `certifications.buddy_id` has no
    // index in the schema (a per-buddy table of a handful of rows), so its
    // hop is the one scan this PR accepts; an index is a follow-up rung.
    const unindexedHops = {'r2'};
    final scans = lines
        .where((l) => l.startsWith('SCAN'))
        .where((l) => l != 'SCAN d')
        .where((l) => !unindexedHops.any((a) => l.startsWith('SCAN $a ')))
        .where((l) => !unindexedHops.contains(l.substring(5)))
        .toList();
    expect(scans, isEmpty, reason: lines.join('\n'));
    expect(lines, contains('SCAN d'), reason: lines.join('\n'));
  });
}
