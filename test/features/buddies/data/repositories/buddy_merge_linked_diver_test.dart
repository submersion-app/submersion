import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late BuddyMergeRepository merges;
  late String owner;
  late String chris;
  late String dana;

  Future<String> diver(String name) async =>
      (await DiverRepository().createDiver(
        Diver(
          id: '',
          name: name,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      )).id;

  Buddy buddy(String name, {String? linked}) => Buddy(
    id: '',
    diverId: owner,
    linkedDiverId: linked,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    merges = BuddyMergeRepository();
    owner = await diver('Eric');
    chris = await diver('Chris');
    dana = await diver('Dana');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('merge carries the single non-null link onto the survivor', () async {
    final survivor = await buddies.createBuddy(buddy('Chris'));
    final dup = await buddies.createBuddy(buddy('C', linked: chris));
    await merges.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: [survivor.id, dup.id],
    );
    expect((await buddies.getBuddyById(survivor.id))?.linkedDiverId, chris);
  });

  test('merge refuses buddies linked to different profiles', () async {
    final a = await buddies.createBuddy(buddy('Chris', linked: chris));
    final b = await buddies.createBuddy(buddy('Dana', linked: dana));
    await expectLater(
      merges.mergeBuddies(mergedBuddy: a, buddyIds: [a.id, b.id]),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('different profiles'),
        ),
      ),
    );
    expect((await buddies.getBuddyById(b.id))?.linkedDiverId, dana);
  });

  test('undo restores a survivor that had no link', () async {
    final survivor = await buddies.createBuddy(buddy('Chris'));
    final dup = await buddies.createBuddy(buddy('C', linked: chris));
    final result = await merges.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: [survivor.id, dup.id],
    );
    await merges.undoMerge(result!.snapshot!);
    expect((await buddies.getBuddyById(survivor.id))?.linkedDiverId, isNull);
    expect((await buddies.getBuddyById(dup.id))?.linkedDiverId, chris);
  });
}
