import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.BuddyWithRole bwr(String id) => domain.BuddyWithRole(
    buddy: domain.Buddy(
      id: id,
      name: 'B$id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    role: BuddyRole.buddy,
  );

  test('bulkAddBuddies links each buddy to each dive', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('x'), bwr('y')]);
    final d1 = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(d1.map((r) => r.buddyId).toSet(), {'x', 'y'});
    final d2 = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d2'))).get();
    expect(d2.length, 2);
  });

  test('buddyCountsForDives returns per-buddy dive counts', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('shared')]);
    await repository.bulkAddBuddies(['d1'], [bwr('onlyD1')]);
    final counts = await repository.buddyCountsForDives(['d1', 'd2']);
    expect(counts['shared'], 2);
    expect(counts['onlyD1'], 1);
    expect(await repository.buddyCountsForDives(const []), isEmpty);
  });

  test('bulkReplaceBuddies overwrites; bulkRemoveBuddies subtracts', () async {
    await repository.bulkAddBuddies(['d1'], [bwr('x'), bwr('y')]);
    await repository.bulkReplaceBuddies(['d1'], [bwr('z')]);
    var rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.map((r) => r.buddyId).toSet(), {'z'});

    await repository.bulkRemoveBuddies(['d1'], ['z']);
    rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows, isEmpty);
  });

  test(
    'bulkAddBuddies updates the role when the link already exists',
    () async {
      await repository.bulkAddBuddies(['d1'], [bwr('x')]); // role buddy
      await repository.bulkAddBuddies(
        ['d1'],
        [
          domain.BuddyWithRole(
            buddy: bwr('x').buddy,
            role: BuddyRole.instructor,
          ),
        ],
      );
      final rows = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1); // not duplicated
      expect(rows.single.role, 'instructor'); // role updated in place
    },
  );
}
