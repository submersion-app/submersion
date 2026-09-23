import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late DiverRepository divers;
  late DiverMergeRepository merges;
  late String eric;
  late String chris;
  late String chris2;

  Future<String> diver(String name, {bool isDefault = false}) async =>
      (await divers.createDiver(
        Diver(
          id: '',
          name: name,
          isDefault: isDefault,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      )).id;

  Buddy buddy(String owner, String name, {String? linked}) => Buddy(
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
    divers = DiverRepository();
    merges = DiverMergeRepository();
    eric = await diver('Eric', isDefault: true);
    chris = await diver('Chris');
    chris2 = await diver('Chris');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('mergeDivers repoints buddies linked to the merged diver', () async {
    final b = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris2));
    await merges.mergeDivers(keeperId: chris, duplicateId: chris2);
    expect((await buddies.getBuddyById(b.id))?.linkedDiverId, chris);
  });

  test(
    'a repointed link that collides with an existing one is cleared',
    () async {
      final keep = await buddies.createBuddy(
        buddy(eric, 'Chris', linked: chris),
      );
      final dup = await buddies.createBuddy(buddy(eric, 'C', linked: chris2));
      await merges.mergeDivers(keeperId: chris, duplicateId: chris2);
      expect((await buddies.getBuddyById(keep.id))?.linkedDiverId, chris);
      expect((await buddies.getBuddyById(dup.id))?.linkedDiverId, isNull);
    },
  );

  test('a link that would point at its own owner is cleared', () async {
    // Chris's own list holds a buddy for the duplicate profile. Repointing
    // it to the keeper would make the buddy link the profile that owns it,
    // which BuddyProfileLinkRepository refuses everywhere else.
    final own = await buddies.createBuddy(buddy(chris, 'Me', linked: chris2));
    await merges.mergeDivers(keeperId: chris, duplicateId: chris2);
    expect((await buddies.getBuddyById(own.id))?.linkedDiverId, isNull);
  });

  test('undoMerge restores the links', () async {
    final moved = await buddies.createBuddy(
      buddy(eric, 'Chris', linked: chris2),
    );
    final dana = await diver('Dana');
    await buddies.createBuddy(buddy(dana, 'Chris', linked: chris));
    final cleared = await buddies.createBuddy(buddy(dana, 'C', linked: chris2));
    final snapshot = await merges.mergeDivers(
      keeperId: chris,
      duplicateId: chris2,
    );
    await merges.undoMerge(snapshot);
    expect((await buddies.getBuddyById(moved.id))?.linkedDiverId, chris2);
    expect((await buddies.getBuddyById(cleared.id))?.linkedDiverId, chris2);
  });

  test('deleting a profile clears links to it', () async {
    final b = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
    await divers.deleteDiverWithReassignment(chris);
    expect((await buddies.getBuddyById(b.id))?.linkedDiverId, isNull);
  });
}
