import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// Issue #3810 as it was reported: the words a diver tried, run against a
/// seeded database, reach the same dives as `trip:none`.
void main() {
  late AppDatabase db;
  final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;

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
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'belize',
            name: 'Belize',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<void> dive(String id, String? trip, {String? notes}) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            diveDateTime: now,
            tripId: Value(trip),
            notes: Value(notes ?? ''),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('on-trip', 'belize');
    await dive('no-trip', null);
    // Words from the phrase in the notes: the search this replaced found
    // this dive and only this one.
    await dive('wordy', 'belize', notes: 'trip is blank');
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 30),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
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

  test('the reporter\'s phrases find the dives with no trip', () async {
    for (final text in const ['Trip is blank', 'Trip is null', 'trip:none']) {
      expect(await ids(text), {'no-trip'}, reason: text);
    }
  });

  test('their opposites find the dives on a trip', () async {
    for (final text in const ['trip is set', 'trip is not null', 'trip:any']) {
      expect(await ids(text), {'on-trip', 'wordy'}, reason: text);
    }
  });

  test('a phrase in quotes still searches the notes', () async {
    expect(await ids('"trip is blank"'), {'wordy'});
  });
}
