import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('VisibilityFilter.sqlFragment', () {
    test('returns empty fragment when diverId is null', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: null,
        conjunction: 'AND',
      );
      expect(frag.whereClause, isEmpty);
      expect(frag.variables, isEmpty);
      expect(frag.isEmpty, isTrue);
    });

    test('builds predicate with AND conjunction and qualified columns', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: 'diver-1',
        conjunction: 'AND',
      );
      expect(
        frag.whereClause,
        equals(' AND (t.diver_id = ? OR t.is_shared = 1)'),
      );
      expect(frag.variables.length, equals(1));
      expect(frag.isEmpty, isFalse);
    });

    test('builds predicate with WHERE conjunction', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 'trips',
        diverId: 'd-1',
        conjunction: 'WHERE',
      );
      expect(
        frag.whereClause,
        equals(' WHERE (trips.diver_id = ? OR trips.is_shared = 1)'),
      );
    });
  });

  group('VisibilityFilter.applyToTrips', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      const t = 1700000000000;
      for (final id in ['A', 'B', 'C']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
    });

    tearDown(() => db.close());

    Future<void> insertTrip(String id, String diverId, bool shared) async {
      const t = 1700000000000;
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: id,
              name: id,
              startDate: t,
              endDate: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(diverId),
              isShared: Value(shared),
            ),
          );
    }

    test('no-op when diverId is null', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, null);
      final rows = await query.get();

      expect(rows.length, equals(2));
    });

    test('returns owned rows for the given diver', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id), equals(['t1']));
    });

    test('returns shared rows regardless of owner', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', true);
      await insertTrip('t3', 'C', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id).toSet(), equals({'t1', 't2'}));
    });
  });

  group('VisibilityFilter.applyToDiveSites', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      const t = 1700000000000;
      for (final id in ['A', 'B', 'C']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
    });

    tearDown(() => db.close());

    Future<void> insertSite(String id, String diverId, bool shared) async {
      const t = 1700000000000;
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(diverId),
              isShared: Value(shared),
            ),
          );
    }

    test('returns owner + shared rows', () async {
      await insertSite('s1', 'A', false);
      await insertSite('s2', 'B', true);
      await insertSite('s3', 'C', false);

      final query = db.select(db.diveSites);
      VisibilityFilter.applyToDiveSites(query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id).toSet(), equals({'s1', 's2'}));
    });
  });
}
