import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// `surfaceInterval` filters on the value the dive table shows (#2984):
/// stored, else the gap from the previous dive. No shared fixture, because
/// its dives would become previous dives.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 10),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  final base = DateTime.utc(2026, 4, 1, 10);
  domain.Dive dive(
    String id,
    int startMinute, {
    int? exitMinute,
    Duration? stored,
  }) => domain.Dive(
    id: id,
    dateTime: base.add(Duration(minutes: startMinute)),
    entryTime: base.add(Duration(minutes: startMinute)),
    exitTime: exitMinute == null
        ? null
        : base.add(Duration(minutes: exitMinute)),
    surfaceInterval: stored,
  );

  test(
    'surfaceInterval filters on the computed gap when none is stored',
    () async {
      await repository.createDive(dive('a', 0, exitMinute: 40));
      await repository.createDive(dive('b', 100));

      expect(await ids('surfaceInterval = 60'), {'b'});
      expect(await ids('surfaceInterval >= 61'), isEmpty);
      expect(await ids('surfaceInterval:none'), {'a'});
    },
  );

  test('a stored interval still wins', () async {
    await repository.createDive(dive('a', 0, exitMinute: 40));
    await repository.createDive(
      dive('b', 100, stored: const Duration(minutes: 15)),
    );

    expect(await ids('surfaceInterval = 15'), {'b'});
  });
}
