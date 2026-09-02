import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../helpers/test_database.dart';

Buddy _buddy({Uint8List? photo}) => Buddy(
  id: 'b-photo-1',
  name: 'Jane Doe',
  photo: photo,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('a photo survives create and read', () async {
    final repo = BuddyRepository();
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));

    await repo.createBuddy(_buddy(photo: bytes));
    final read = await repo.getBuddyById('b-photo-1');

    expect(read, isNotNull);
    expect(read!.photo, bytes);
  });

  test('updating to a new photo replaces the stored bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy(photo: Uint8List.fromList([1, 2, 3])));

    final replacement = Uint8List.fromList([9, 9, 9, 9]);
    await repo.updateBuddy(_buddy(photo: replacement));
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, replacement);
  });

  test('updating with a cleared photo removes the stored bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy(photo: Uint8List.fromList([1, 2, 3])));

    await repo.updateBuddy(
      _buddy(photo: Uint8List.fromList([1, 2, 3])).clearPhoto(),
    );
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, isNull);
  });

  test('a buddy with no photo reads back null, not empty bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy());
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, isNull);
  });

  test('a photo survives the getAllBuddies read path too', () async {
    // getBuddyById and the list reads use DIFFERENT mappers in this
    // repository, so covering only one would leave the other silently
    // dropping the photo.
    final repo = BuddyRepository();
    final bytes = Uint8List.fromList(List.generate(32, (i) => 255 - i));

    await repo.createBuddy(_buddy(photo: bytes));
    final all = await repo.getAllBuddies();

    final found = all.firstWhere((b) => b.id == 'b-photo-1');
    expect(found.photo, bytes);
  });
}
