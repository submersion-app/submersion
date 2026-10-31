import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// A buddy edit reads the original links once, leanly and in bounded batches,
/// however many operations and dives it covers (#4011).
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;
  late BuddyRepository buddyRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    buddyRepo = BuddyRepository();
    service = BulkDiveEditService(diveRepo, buddyRepo, SpeciesRepository());
  });

  tearDown(tearDownTestDatabase);

  Future<void> seedDive(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
  );

  Future<void> seedBuddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  domain.Buddy person(String id) => domain.Buddy(
    id: id,
    name: id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  domain.BuddyWithRole withRoles(String id, List<String> roleIds) =>
      domain.BuddyWithRole(
        buddy: person(id),
        roles: [for (final roleId in roleIds) DiveRole.synthetic(roleId)],
      );

  // Every shape the bulk form can send in one save: a membership-only add, an
  // add with chosen roles, a role-only update and a removal.
  List<BulkCollectionOp> fourBuddyOps() => [
    BuddiesOp(
      mode: BulkCollectionMode.add,
      buddies: [
        withRoles('cara', const ['buddy']),
      ],
      overwriteRole: false,
    ),
    BuddiesOp(
      mode: BulkCollectionMode.add,
      buddies: [
        withRoles('dan', const ['instructor']),
      ],
    ),
    BuddiesOp(
      mode: BulkCollectionMode.update,
      buddies: [
        withRoles('ana', const ['diveGuide']),
      ],
    ),
    BuddiesOp(
      mode: BulkCollectionMode.remove,
      buddies: [
        withRoles('ben', const ['buddy']),
      ],
    ),
  ];

  /// Statements [req] sends before the write transaction opens, which is
  /// where the undo snapshot is captured.
  Future<List<String>> statementsBeforeWrites(BulkEditRequest req) async {
    final logged = <String>[];
    await runZoned(
      () => service.apply(req),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    return logged
        .where((line) => line.startsWith('Drift: Sent'))
        .takeWhile((line) => !line.contains('BEGIN'))
        .toList();
  }

  Future<Map<String, Map<String, List<String>>>> membership(
    List<String> ids,
  ) async {
    final byDive = await buddyRepo.getBuddiesForDives(ids);
    return {
      for (final id in ids)
        id: {
          for (final row in byDive[id] ?? const <domain.BuddyWithRole>[])
            row.buddy.id: row.roleIds,
        },
    };
  }

  Future<List<String>> seedSelection(String prefix, int dives) async {
    final ids = [for (var i = 0; i < dives; i++) '$prefix$i'];
    for (final id in ids) {
      await seedDive(id);
      await buddyRepo.setBuddiesForDive(id, [
        withRoles('ana', const ['diveMaster']),
        withRoles('ben', const ['buddy']),
      ]);
    }
    return ids;
  }

  Future<void> seedPeople() async {
    for (final id in const ['ana', 'ben', 'cara', 'dan']) {
      await seedBuddy(id);
    }
  }

  test('four buddy operations read no more than one', () async {
    await seedPeople();
    final oneOp = await seedSelection('one', 4);
    final fourOps = await seedSelection('four', 4);

    final single = await statementsBeforeWrites(
      BulkEditRequest(diveIds: oneOp, ops: [fourBuddyOps().first]),
    );
    final repeated = await statementsBeforeWrites(
      BulkEditRequest(diveIds: fourOps, ops: fourBuddyOps()),
    );

    expect(repeated, hasLength(single.length));
  });

  test('snapshot reads do not grow with the selection', () async {
    await seedPeople();
    final small = await seedSelection('small', 2);
    final large = await seedSelection('large', 12);

    final fewDives = await statementsBeforeWrites(
      BulkEditRequest(diveIds: small, ops: fourBuddyOps()),
    );
    final manyDives = await statementsBeforeWrites(
      BulkEditRequest(diveIds: large, ops: fourBuddyOps()),
    );

    expect(manyDives, hasLength(fewDives.length));
  });

  test('the snapshot reads no certification data', () async {
    await seedPeople();
    final ids = await seedSelection('dive', 3);

    final statements = await statementsBeforeWrites(
      BulkEditRequest(diveIds: ids, ops: fourBuddyOps()),
    );

    expect(statements.where((line) => line.contains('certification')), isEmpty);
  });

  test('every selected dive gets an entry, empty or not', () async {
    await seedPeople();
    await seedDive('linked');
    await seedDive('empty');
    await buddyRepo.setBuddiesForDive('linked', [
      withRoles('ana', const ['diveMaster']),
    ]);

    final snapshot = await service.apply(
      BulkEditRequest(diveIds: const ['linked', 'empty'], ops: fourBuddyOps()),
    );

    expect(snapshot.priorBuddies!.keys, unorderedEquals(['linked', 'empty']));
    expect(snapshot.priorBuddies!['linked'], hasLength(1));
    expect(snapshot.priorBuddies!['empty'], isEmpty);
  });

  test('undo restores role sets, empty dives and mixed presence', () async {
    await seedPeople();
    for (final id in const ['full', 'partial', 'empty']) {
      await seedDive(id);
    }
    await buddyRepo.setBuddiesForDive('full', [
      withRoles('ana', const ['diveMaster', 'instructor']),
      withRoles('ben', const ['buddy']),
    ]);
    // A role id with no catalog row still has to come back as written.
    await buddyRepo.setBuddiesForDive('partial', [
      withRoles('ana', const ['roleNoLongerInCatalog']),
    ]);
    const ids = ['full', 'partial', 'empty'];
    final original = await membership(ids);

    final snapshot = await service.apply(
      BulkEditRequest(diveIds: ids, ops: fourBuddyOps()),
    );
    final edited = await membership(ids);
    expect(edited['full']!.keys, unorderedEquals(['ana', 'cara', 'dan']));
    expect(edited['empty']!.keys, unorderedEquals(['cara', 'dan']));

    await service.undo(snapshot);

    expect(await membership(ids), original);
  });
}
