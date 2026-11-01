import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

/// Merging buddies keeps their places: links on a merged-away buddy move to
/// the survivor, and the merge's undo restores each place's own link
/// (issue #3790).
void main() {
  late AppDatabase db;
  final repo = BuddyRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestBuddy(id: 'keep', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'dup', name: 'Alex R', diverId: 'A');
    await insertTestBuddy(id: 'dup2', name: 'A. R.', diverId: 'A');
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertPlace(String id, String buddyId) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          diverId: const Value('A'),
          name: id,
          kind: const Value('person'),
          buddyId: Value(buddyId),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<Map<String, String?>> links() async => {
    for (final r in await db.select(db.equipmentLocations).get())
      r.id: r.buddyId,
  };

  Future<bool> isPending(String id) async =>
      (await db.select(db.syncRecords).get()).any(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == id,
      );

  Future<BuddyMergeResult> merge() async {
    final survivor = (await repo.getBuddyById('keep'))!;
    return (await repo.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: ['keep', 'dup', 'dup2'],
    ))!;
  }

  test('links on merged-away buddies move to the survivor', () async {
    await insertPlace('a', 'keep');
    await insertPlace('b', 'dup');
    await insertPlace('c', 'dup2');

    await merge();

    expect(await links(), {'a': 'keep', 'b': 'keep', 'c': 'keep'});
    expect(await isPending('b'), isTrue);
    expect(await isPending('c'), isTrue);
    expect(await isPending('a'), isFalse);
  });

  test('undo restores each place to its own buddy', () async {
    await insertPlace('a', 'keep');
    await insertPlace('b', 'dup');
    await insertPlace('c', 'dup2');
    final result = await merge();

    await repo.undoMerge(result.snapshot!);

    expect(await links(), {'a': 'keep', 'b': 'dup', 'c': 'dup2'});
  });
}
