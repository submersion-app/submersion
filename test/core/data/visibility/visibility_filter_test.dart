import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('VisibilityFilter.sqlFragment', () {
    test('returns empty fragment when diverId is null', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: null,
        conjunction: 'AND',
        kind: SharedItemKind.trip,
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
        kind: SharedItemKind.trip,
      );
      expect(
        frag.whereClause,
        equals(
          ' AND (t.diver_id = ? OR t.is_shared = 1 OR t.id IN '
          '(SELECT trip_id FROM trip_shares WHERE diver_id = ?))'
          ' AND t.id NOT IN (SELECT trip_id FROM trip_hides WHERE diver_id = ?)',
        ),
      );
      expect(frag.variables.length, equals(3));
      expect(frag.isEmpty, isFalse);
    });

    test('builds predicate with WHERE conjunction', () {
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 'trips',
        diverId: 'd-1',
        conjunction: 'WHERE',
        kind: SharedItemKind.site,
      );
      expect(
        frag.whereClause,
        equals(
          ' WHERE (trips.diver_id = ? OR trips.is_shared = 1 OR '
          '(trips.shared_library_id IS NULL AND trips.id IN '
          '(SELECT site_id FROM site_shares WHERE diver_id = ?)) OR '
          'trips.shared_library_id IN (SELECT library_id FROM '
          'shared_library_memberships WHERE diver_id = ?))'
          ' AND trips.id NOT IN '
          '(SELECT site_id FROM site_hides WHERE diver_id = ?)',
        ),
      );
    });
  });

  test('ownerOrSharedSql names the viewer by any SQL expression', () {
    // hiddenItems binds the viewer through its join (issue #2678).
    expect(
      VisibilityFilter.ownerOrSharedSql('t', 'h.diver_id'),
      '(t.diver_id = h.diver_id OR t.is_shared = 1 OR t.id IN '
      '(SELECT trip_id FROM trip_shares WHERE diver_id = h.diver_id))',
    );
  });

  group('VisibilityFilter.applyToTrips', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
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
      VisibilityFilter.applyToTrips(db, query, null);
      final rows = await query.get();

      expect(rows.length, equals(2));
    });

    test('returns owned rows for the given diver', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(db, query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id), equals(['t1']));
    });

    test('returns shared rows regardless of owner', () async {
      await insertTrip('t1', 'A', false);
      await insertTrip('t2', 'B', true);
      await insertTrip('t3', 'C', false);

      final query = db.select(db.trips);
      VisibilityFilter.applyToTrips(db, query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id).toSet(), equals({'t1', 't2'}));
    });

    test('a trip shared with B is visible to B and not to C', () async {
      await insertTrip('t1', 'A', false);
      await db
          .into(db.tripShares)
          .insert(
            TripSharesCompanion.insert(
              id: 'x',
              tripId: 't1',
              diverId: 'B',
              createdAt: 0,
            ),
          );
      Future<List<String>> visibleTo(String diverId) async {
        final query = db.select(db.trips);
        VisibilityFilter.applyToTrips(db, query, diverId);
        return [for (final r in await query.get()) r.id];
      }

      expect(await visibleTo('B'), ['t1']);
      expect(await visibleTo('C'), isEmpty);
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: 'B',
        conjunction: 'WHERE',
        kind: SharedItemKind.trip,
      );
      final raw = await db
          .customSelect(
            'SELECT t.id FROM trips t${frag.whereClause}',
            variables: frag.variables,
          )
          .get();
      expect(raw.map((r) => r.read<String>('id')), ['t1']);
    });
  });

  group('VisibilityFilter.applyToDiveSites', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
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
      VisibilityFilter.applyToDiveSites(db, query, 'A');
      final rows = await query.get();

      expect(rows.map((r) => r.id).toSet(), equals({'s1', 's2'}));
    });

    test('a share row never shows a shared site library site to a profile '
        'outside the library', () async {
      // Pushed into a library after it was shared with B by name: the
      // library's membership governs it from then on.
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 'lib-site',
              name: 'lib-site',
              createdAt: 0,
              updatedAt: 0,
              sharedLibraryId: const Value('lib1'),
            ),
          );
      await db
          .into(db.siteShares)
          .insert(
            SiteSharesCompanion.insert(
              id: 'x',
              siteId: 'lib-site',
              diverId: 'B',
              createdAt: 0,
            ),
          );
      final query = db.select(db.diveSites);
      VisibilityFilter.applyToDiveSites(db, query, 'B');
      expect(await query.get(), isEmpty);
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 's',
        diverId: 'B',
        conjunction: 'WHERE',
        kind: SharedItemKind.site,
      );
      final raw = await db
          .customSelect(
            'SELECT s.id FROM dive_sites s${frag.whereClause}',
            variables: frag.variables,
          )
          .get();
      expect(raw, isEmpty);
    });

    test('a site shared with B is visible to B and not to C', () async {
      await insertSite('s1', 'A', false);
      await db
          .into(db.siteShares)
          .insert(
            SiteSharesCompanion.insert(
              id: 'x',
              siteId: 's1',
              diverId: 'B',
              createdAt: 0,
            ),
          );
      Future<List<String>> visibleTo(String diverId) async {
        final query = db.select(db.diveSites);
        VisibilityFilter.applyToDiveSites(db, query, diverId);
        return [for (final r in await query.get()) r.id];
      }

      expect(await visibleTo('B'), ['s1']);
      expect(await visibleTo('C'), isEmpty);
      final frag = VisibilityFilter.sqlFragment(
        tableAlias: 's',
        diverId: 'B',
        conjunction: 'WHERE',
        kind: SharedItemKind.site,
      );
      final raw = await db
          .customSelect(
            'SELECT s.id FROM dive_sites s${frag.whereClause}',
            variables: frag.variables,
          )
          .get();
      expect(raw.map((r) => r.read<String>('id')), ['s1']);
    });
  });

  group('equipmentSqlFragment', () {
    test('is empty for a null diver', () {
      final f = VisibilityFilter.equipmentSqlFragment(
        tableAlias: 'e',
        diverId: null,
        conjunction: 'AND',
      );
      expect(f.isEmpty, isTrue);
    });
    test('binds the diver twice', () {
      final f = VisibilityFilter.equipmentSqlFragment(
        tableAlias: 'e',
        diverId: 'd1',
        conjunction: 'WHERE',
      );
      expect(f.whereClause, contains('WHERE (e.diver_id = ? OR e.id IN'));
      expect(f.variables, hasLength(2));
    });
  });

  group('VisibilityFilter.equipmentVisibleTo', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
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
      for (final (id, owner) in [('e1', 'A'), ('e2', 'B'), ('e3', 'C')]) {
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: id,
                name: id,
                type: 'tank',
                createdAt: t,
                updatedAt: t,
                diverId: Value(owner),
              ),
            );
      }
      // B shares e2 with A.
      await db
          .into(db.equipmentShares)
          .insert(
            EquipmentSharesCompanion.insert(
              id: 'sh1',
              equipmentId: 'e2',
              diverId: 'A',
              createdAt: t,
            ),
          );
    });

    tearDown(() => db.close());

    test('is null for a null diver', () {
      expect(
        VisibilityFilter.equipmentVisibleTo(db, db.equipment, null),
        isNull,
      );
    });

    test('matches owned and shared items only', () async {
      final query = db.select(db.equipment)
        ..where((t) => VisibilityFilter.equipmentVisibleTo(db, t, 'A')!);
      final rows = await query.get();
      expect(rows.map((r) => r.id).toSet(), {'e1', 'e2'});
    });
  });
}
