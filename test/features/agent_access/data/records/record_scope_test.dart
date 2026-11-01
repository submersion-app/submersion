import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const a = 'diver-a';
  const b = 'diver-b';
  const t = 1700000000000;

  Future<Set<String>> idsFor(
    String table,
    RecordScope scope,
    String diverId,
  ) async {
    final s = scope(diverId, 'r0');
    final rows = await db
        .customSelect(
          'SELECT r0.id AS id FROM $table r0'
          '${s == null ? '' : ' WHERE ${s.sql}'}',
          variables: [
            if (s != null)
              for (final p in s.params) Variable<Object>(p),
          ],
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in [a, b]) {
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
    for (final (id, owner) in [('own', a), ('other', b), ('none', null)]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    for (final (id, owner, builtIn) in [
      ('mine', a, false),
      ('theirs', b, false),
      ('stock', null, true),
      ('orphan', null, false),
    ]) {
      await db
          .into(db.serviceKinds)
          .insert(
            ServiceKindsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              isBuiltIn: Value(builtIn),
            ),
          );
    }
    for (final (id, owner, shared) in [
      ('private', a, false),
      ('other-private', b, false),
      ('other-shared', b, true),
    ]) {
      await db
          .into(db.customCertificationAgencies)
          .insert(
            CustomCertificationAgenciesCompanion.insert(
              id: id,
              diverId: owner,
              name: id,
              colorArgb: 0,
              createdAt: t,
              updatedAt: t,
              isShared: Value(shared),
            ),
          );
    }
    for (final (id, owner, shared) in [
      ('open', b, true),
      ('closed', b, false),
    ]) {
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
              diverId: Value(owner),
              isShared: Value(shared),
            ),
          );
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: 'cyl-$id',
              tripId: id,
              label: Value(id),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.tripCylinderEvents)
          .insert(
            TripCylinderEventsCompanion.insert(
              id: 'evt-$id',
              tripCylinderId: 'cyl-$id',
              kind: 'fill',
              occurredAt: t,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });

  tearDown(() => db.close());

  test('everyone returns null', () {
    expect(everyone()(a, 'r0'), isNull);
  });

  test('owned keeps only the diver\'s rows', () async {
    expect(await idsFor('tags', owned(), a), {'own'});
  });

  test('ownedOrNull adds the ownerless rows', () async {
    expect(await idsFor('tags', ownedOrNull(), a), {'own', 'none'});
  });

  // The schema seeds its own built-in kinds, so these name only the seeded
  // custom rows.
  test('ownedOrBuiltIn leaves ownerless custom rows out', () async {
    final ids = await idsFor('service_kinds', ownedOrBuiltIn(), a);
    expect(ids, containsAll(['mine', 'stock']));
    expect(ids, isNot(contains('orphan')));
    expect(ids, isNot(contains('theirs')));
  });

  test('ownedNullOrBuiltIn takes both', () async {
    final ids = await idsFor('service_kinds', ownedNullOrBuiltIn(), a);
    expect(ids, containsAll(['mine', 'stock', 'orphan']));
    expect(ids, isNot(contains('theirs')));
  });

  test('ownedOrShared adds what another profile shared', () async {
    expect(await idsFor('custom_certification_agencies', ownedOrShared(), a), {
      'private',
      'other-shared',
    });
  });

  test('rootScope delegates to the query root rule', () async {
    expect(await idsFor('trips', rootScope(QuerySubject.trips), a), {'open'});
    expect(await idsFor('trips', rootScope(QuerySubject.trips), b), {
      'open',
      'closed',
    });
  });

  test('viaParent follows the parent rule', () async {
    final scope = viaParent('trips', 'trip_id', rootScope(QuerySubject.trips));
    expect(await idsFor('trip_cylinders', scope, a), {'cyl-open'});
  });

  test('viaParent nests two levels', () async {
    final scope = viaParent(
      'trip_cylinders',
      'trip_cylinder_id',
      viaParent('trips', 'trip_id', rootScope(QuerySubject.trips)),
    );
    expect(await idsFor('trip_cylinder_events', scope, a), {'evt-open'});
  });

  test('viaParent over everyone has no parameters', () {
    final scope = viaParent('species', 'species_id', everyone())(a, 'r0')!;
    expect(scope.params, isEmpty);
    expect(scope.sql, contains('r0.species_id IN'));
  });

  test('viaParent keeps parameters in order', () {
    final scope = viaParent('trips', 'trip_id', rootScope(QuerySubject.trips))(
      a,
      'r0',
    )!;
    expect('?'.allMatches(scope.sql).length, scope.params.length);
    expect(scope.params.every((p) => p == a), isTrue);
  });
}
