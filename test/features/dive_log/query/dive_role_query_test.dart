import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// The diver's own role on a dive (#3622): `role:none` keeps dives whose
/// role is not set, and `role:any` the rest. A null or blank
/// `dives.diver_role` is no role whatever the junction holds, as
/// `DiveRoleSet.resolve` reads it.
void main() {
  late AppDatabase db;
  final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    Future<void> dive(String id, String? role, {String diver = 'me'}) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diver),
            diveDateTime: now,
            diverRole: Value(role),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('unset', null);
    await dive('blank', '');
    await dive('instructor', 'instructor');
    await dive('custom', 'a1b2c3-custom-role');
    // A junction row an older version's cleared scalar outdates.
    await dive('stale', null);
    await db
        .into(db.diveDiverRoles)
        .insert(
          DiveDiverRolesCompanion.insert(
            id: 'r1',
            diveId: 'stale',
            roleId: 'diveGuide',
            createdAt: now,
          ),
        );
    await dive('theirs', null, diver: 'other');
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 25),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> idsWhere(String where, List<Object?> params) async {
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND $where',
          variables: [
            const Variable<String>('me'),
            ...params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    return idsWhere(q.where, q.params);
  }

  test('role:none keeps dives whose role is not set', () async {
    expect(await ids('role:none'), {'unset', 'blank', 'stale'});
  });

  test('role:any keeps dives with a role, built-in or custom', () async {
    expect(await ids('role:any'), {'instructor', 'custom'});
  });

  test('myRole is an alias of role', () async {
    expect(await ids('myRole:none'), {'unset', 'blank', 'stale'});
  });

  test('a named role is refused, not silently matched', () {
    final parsed = parser.parse('role:instructor');
    expect(parsed, isA<ParseFailure>());
    expect(
      (parsed as ParseFailure).error.code,
      QueryErrorCode.opNotForFieldQuoted,
    );
  });

  test('the No role filter axis matches role:none', () async {
    final q = compileDiveFilter(
      const DiveFilterState(noRoleOnly: true),
      rootAlias: 'd',
    );
    expect(await idsWhere(q.where, q.params), {'unset', 'blank', 'stale'});
  });
}
