import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../helpers/test_database.dart';

/// Buddy card fields (issue #3728) survive create, update and read.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => DatabaseService.instance.resetForTesting());

  final carded = Buddy(
    id: 'b-card-1',
    name: 'Sam Rivera',
    cardId: 'diver-sam',
    socialHandle: '@samdives',
    cardDiveCount: 118,
    cardDivingSince: DateTime(2016),
    cardLastDive: DateTime(2026, 10, 3),
    cardReceivedAt: DateTime(2026, 10, 28, 14, 30),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('card fields survive create and read', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(carded);
    final read = await repo.getBuddyById(carded.id);

    expect(read!.cardId, 'diver-sam');
    expect(read.socialHandle, '@samdives');
    expect(read.cardDiveCount, 118);
    expect(read.cardDivingSince, DateTime(2016));
    expect(read.cardLastDive, DateTime(2026, 10, 3));
    expect(read.cardReceivedAt, DateTime(2026, 10, 28, 14, 30));
  });

  test('updating card fields replaces them', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(carded);
    await repo.updateBuddy(
      carded.copyWith(cardDiveCount: 120, socialHandle: '@sam'),
    );
    final read = await repo.getBuddyById(carded.id);

    expect(read!.cardDiveCount, 120);
    expect(read.socialHandle, '@sam');
    expect(read.cardId, 'diver-sam');
  });

  test('clearPhoto and clearLinkedDiver keep the card fields', () {
    expect(carded.clearPhoto().cardDiveCount, 118);
    expect(carded.clearLinkedDiver().cardId, 'diver-sam');
  });
}
