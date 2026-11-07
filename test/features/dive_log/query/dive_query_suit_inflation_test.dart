import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// A suit inflation bottle is not the dive's gas (issue #4243): an air argon
/// bottle on a nitrox dive must not make it an air dive in a search.
///
/// nx: EAN32 back gas and an air suit bottle. air: air back gas.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 6).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value('me'),
            name: const Value('Me'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    Future<void> dive(String id) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: const Value('me'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    Future<void> tank(String id, String diveId, String role, double o2) => db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            tankRole: Value(role),
            o2Percent: Value(o2),
            hePercent: const Value(0.0),
          ),
        );
    await dive('nx');
    await tank('nx-suit', 'nx', 'suitInflation', 21);
    await tank('nx-back', 'nx', 'backGas', 32);
    await dive('air');
    await tank('air-back', 'air', 'backGas', 21);
  });

  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);

  Future<Set<String>> ids(String text) async {
    final parsed = QueryParser(
      appQueryRegistry,
      dives,
      ParseContext(
        prefs: kMetricPrefs,
        now: DateTime(2026, 11, 6),
        names: const MapNameResolver({}),
      ),
    ).parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
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

  test('the gas words read the breathing gas', () async {
    expect(await ids('air'), {'air'});
    expect(await ids('nitrox'), {'nx'});
    expect(await ids('ean21'), {'air'});
  });

  test('a tank O2 condition ignores the bottle', () async {
    expect(await ids('tanks.o2 <= 21'), {'air'});
  });

  test("the dive filter's O2 range ignores the bottle", () async {
    final node = const DiveFilterState(maxO2Percent: 22).toQuery();
    final q = compileQuery(node!, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')).toSet(), {'air'});
  });
}
