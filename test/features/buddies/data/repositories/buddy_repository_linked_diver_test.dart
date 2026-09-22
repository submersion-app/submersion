import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late String ownerId;
  late String chrisId;

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    final divers = DiverRepository();
    ownerId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'Eric',
        isDefault: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
    chrisId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'Chris',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Buddy buddy({String? linkedDiverId}) => Buddy(
    id: '',
    diverId: ownerId,
    linkedDiverId: linkedDiverId,
    name: 'Chris',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('createBuddy stores the link and getBuddyById reads it back', () async {
    final created = await buddies.createBuddy(buddy(linkedDiverId: chrisId));
    final read = await buddies.getBuddyById(created.id);
    expect(read?.linkedDiverId, chrisId);
  });

  test('updateBuddy writes the link and clearLinkedDiver removes it', () async {
    final created = await buddies.createBuddy(buddy());
    await buddies.updateBuddy(created.copyWith(linkedDiverId: chrisId));
    expect((await buddies.getBuddyById(created.id))?.linkedDiverId, chrisId);
    await buddies.updateBuddy(created.clearLinkedDiver());
    expect((await buddies.getBuddyById(created.id))?.linkedDiverId, isNull);
  });

  test('getAllBuddies carries the link', () async {
    await buddies.createBuddy(buddy(linkedDiverId: chrisId));
    final all = await buddies.getAllBuddies(diverId: ownerId);
    expect(all.single.linkedDiverId, chrisId);
  });
}
