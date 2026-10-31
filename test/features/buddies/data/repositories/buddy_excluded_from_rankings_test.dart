import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3624: the rankings exclusion survives every path that writes a
/// buddy row, so a save, a merge or an undo cannot quietly rank them again.
void main() {
  late BuddyRepository buddies;
  late BuddyMergeRepository merges;

  Buddy buddy(String name, {bool excluded = false}) => Buddy(
    id: '',
    name: name,
    excludedFromRankings: excluded,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    merges = BuddyMergeRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a new buddy is ranked unless told otherwise', () async {
    final ranked = await buddies.createBuddy(buddy('Anna'));

    final read = await buddies.getBuddyById(ranked.id);

    expect(read?.excludedFromRankings, isFalse);
  });

  test('create and update both store the flag', () async {
    final created = await buddies.createBuddy(buddy('Unknown', excluded: true));
    expect(
      (await buddies.getBuddyById(created.id))?.excludedFromRankings,
      isTrue,
    );

    await buddies.updateBuddy(created.copyWith(excludedFromRankings: false));

    expect(
      (await buddies.getBuddyById(created.id))?.excludedFromRankings,
      isFalse,
    );
  });

  test('a merge stores what the merged buddy says', () async {
    final anna = await buddies.createBuddy(buddy('Anna'));
    final unknown = await buddies.createBuddy(buddy('Unknown', excluded: true));

    await merges.mergeBuddies(
      mergedBuddy: anna,
      buddyIds: [anna.id, unknown.id],
    );

    expect(
      (await buddies.getBuddyById(anna.id))?.excludedFromRankings,
      isFalse,
    );
  });

  test('undoing a merge puts each buddy\'s flag back', () async {
    final unknown = await buddies.createBuddy(buddy('Unknown', excluded: true));
    final anna = await buddies.createBuddy(buddy('Anna'));

    final result = await merges.mergeBuddies(
      mergedBuddy: unknown.copyWith(excludedFromRankings: false),
      buddyIds: [unknown.id, anna.id],
    );
    await merges.undoMerge(result!.snapshot!);

    expect(
      (await buddies.getBuddyById(unknown.id))?.excludedFromRankings,
      isTrue,
      reason: 'the survivor gets its pre-merge flag back',
    );
    expect(
      (await buddies.getBuddyById(anna.id))?.excludedFromRankings,
      isFalse,
      reason: 'the deleted buddy is restored as it was',
    );
  });
}
