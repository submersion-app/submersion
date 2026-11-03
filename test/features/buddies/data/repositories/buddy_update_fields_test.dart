import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const seeded = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'b1',
            name: 'Ana',
            email: const Value('ana@example.com'),
            phone: const Value('+1 555'),
            createdAt: seeded,
            updatedAt: seeded,
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  Future<Buddy> row() =>
      (db.select(db.buddies)..where((t) => t.id.equals('b1'))).getSingle();

  Future<int> pending() async {
    final rows =
        await (db.select(db.syncRecords)..where(
              (t) => t.entityType.equals('buddies') & t.recordId.equals('b1'),
            ))
            .get();
    return rows.length;
  }

  test(
    'updateFields clears a nullable column and stamps the row pending',
    () async {
      await BuddyRepository().updateFields(
        'b1',
        const BuddiesCompanion(email: Value(null)),
      );

      final after = await row();
      expect(after.email, isNull);
      expect(after.phone, '+1 555');
      expect(after.name, 'Ana');
      expect(after.updatedAt, greaterThan(seeded));
      expect(await pending(), 1);
    },
  );

  test('an empty companion writes nothing', () async {
    await BuddyRepository().updateFields('b1', const BuddiesCompanion());

    expect((await row()).updatedAt, seeded);
    expect(await pending(), 0);
  });
}
