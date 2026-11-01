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
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BuddyRepository repository;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = BuddyRepository();
    await db
        .into(db.buddies)
        .insert(
          const BuddiesCompanion(
            id: Value('ana'),
            name: Value('Ana'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final id in const ['d1', 'd2', 'd3', 'd4', 'd5']) {
      await DiveRepository().createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
      );
    }
    final ana = domain.BuddyWithRole(
      buddy: domain.Buddy(
        id: 'ana',
        name: 'Ana',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      roles: [DiveRole.synthetic('diveMaster')],
    );
    // One on each side of the chunk boundary, with empty dives between.
    await repository.setBuddiesForDive('d1', [ana]);
    await repository.setBuddiesForDive('d5', [ana]);
  });

  tearDown(tearDownTestDatabase);

  test('getBuddiesForDivesInChunks answers for every dive', () async {
    const ids = ['d1', 'd2', 'd3', 'd4', 'd5'];

    final byDive = await repository.getBuddiesForDivesInChunks(
      ids,
      chunkSize: 2,
    );

    expect(byDive.keys, unorderedEquals(ids));
    expect(byDive['d1']!.single.roleIds, ['diveMaster']);
    expect(byDive['d5']!.single.roleIds, ['diveMaster']);
    for (final id in const ['d2', 'd3', 'd4']) {
      expect(byDive[id], isEmpty);
    }
  });

  test('getBuddiesForDivesInChunks binds a run of ids per statement', () async {
    const ids = ['d1', 'd2', 'd3', 'd4', 'd5'];
    final logged = <String>[];

    await runZoned(
      () => repository.getBuddiesForDivesInChunks(ids, chunkSize: 2),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );

    // Matches the opening columns: a long statement reaches print in pieces,
    // so the JOIN keyword is on a later line than "Drift: Sent".
    final joins = logged.where(
      (line) => line.startsWith('Drift: Sent') && line.contains('"buddies.id"'),
    );
    expect(joins, hasLength(3));
  });

  test('getBuddiesForDives shares one record per person', () async {
    final byDive = await repository.getBuddiesForDives(const ['d1', 'd5']);

    // The record carries the photo bytes, which a long-lived snapshot would
    // otherwise hold once per dive.
    expect(
      identical(byDive['d1']!.single.buddy, byDive['d5']!.single.buddy),
      isTrue,
    );
  });

  test('getBuddiesForDivesInChunks shares a person across chunks', () async {
    final byDive = await repository.getBuddiesForDivesInChunks(const [
      'd1',
      'd2',
      'd3',
      'd4',
      'd5',
    ], chunkSize: 2);

    expect(
      identical(byDive['d1']!.single.buddy, byDive['d5']!.single.buddy),
      isTrue,
    );
  });

  test('getBuddiesForDivesInChunks is empty for no dives', () async {
    expect(await repository.getBuddiesForDivesInChunks(const []), isEmpty);
  });
}
