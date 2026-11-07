import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// The buddy list read for a handful of ids (issue #4247): Global Search
/// draws up to five buddies and must not read every buddy's dives and roles.
void main() {
  late BuddyRepository repository;
  late db.AppDatabase database;

  Future<void> seed() async {
    final now = DateTime(2026, 1, 1);
    final ms = DateTime.utc(2024, 1, 10).millisecondsSinceEpoch;
    for (final id in const ['ann', 'ben', 'cat']) {
      await repository.createBuddy(
        Buddy(id: id, name: id, createdAt: now, updatedAt: now),
      );
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion(
              id: Value('dive-$id'),
              diveDateTime: Value(ms),
              createdAt: Value(ms),
              updatedAt: Value(ms),
            ),
          );
      await database
          .into(database.diveBuddies)
          .insert(
            db.DiveBuddiesCompanion(
              id: Value('link-$id'),
              diveId: Value('dive-$id'),
              buddyId: Value(id),
              role: const Value(DiveRole.instructorId),
              createdAt: Value(ms),
            ),
          );
    }
  }

  setUp(() async {
    database = await setUpStatementLoggingTestDatabase();
    repository = BuddyRepository();
    await withoutStatementLog(seed);
  });

  tearDown(tearDownTestDatabase);

  test('holds what the list holds for those buddies, and no others', () async {
    final list = await withoutStatementLog(
      repository.getAllBuddiesWithDiveCount,
    );

    final scoped = await withoutStatementLog(
      () => repository.getAllBuddiesWithDiveCount(ids: const ['cat', 'ann']),
    );

    expect(scoped.toSet(), list.where((e) => e.buddy.id != 'ben').toSet());
    expect(scoped.first.diveCount, 1);
    expect(scoped.first.usualRoleId, DiveRole.instructorId);
  });

  test('every statement it sends is narrowed to the ids', () async {
    final sent = await wholeStatementsOf(
      () => repository.getAllBuddiesWithDiveCount(ids: const ['ann']),
    );

    expect(sent, isNotEmpty);
    // The certification catalog names a cert's agency and level; it holds
    // no buddy rows.
    final perBuddy = sent.where(
      (s) => !s.contains(RegExp(r'FROM "custom_certification_\w+"')),
    );
    for (final statement in perBuddy) {
      expect(statement, contains('ann'), reason: statement);
    }
  });

  test('reads nothing for no ids', () async {
    final sent = await wholeStatementsOf(
      () async => expect(
        await repository.getAllBuddiesWithDiveCount(ids: const []),
        isEmpty,
      ),
    );

    expect(sent, isEmpty);
  });
}
