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

void main() {
  late AppDatabase db;
  const now = 1735689600000; // 2025-01-01

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<void> trip(
      String id, {
      String type = 'shore',
      String? liveaboard,
      bool shared = false,
    }) => db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: id,
            diverId: const Value('me'),
            name: id,
            startDate: now,
            endDate: now,
            tripType: Value(type),
            liveaboardName: Value(liveaboard),
            isShared: Value(shared),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await trip('boat', type: 'liveaboard', liveaboard: 'Aurora');
    await trip('beach', shared: true);
    await trip('home');
    Future<void> dive(String id, String tripId) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            tripId: Value(tripId),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('d1', 'boat');
    await dive('d2', 'beach');
  });
  tearDown(tearDownTestDatabase);

  final trips = appQueryRegistry.entityFor(QuerySubject.trips);
  final parser = QueryParser(
    appQueryRegistry,
    trips,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, trips, appQueryRegistry), isEmpty);
    final q = compileQuery(node, trips, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('trip type, sharing and dives are queryable', () async {
    expect(await ids('tripType = liveaboard'), {'boat'});
    expect(await ids('shared = true'), {'beach'});
    expect(await ids('dives:none'), {'home'});
    expect(await ids('"auro"'), {'boat'});
  });
}
