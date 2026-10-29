import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

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

  test('the last dive is stored as a calendar date, the same in every time '
      'zone', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(carded);
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.buddies,
    )..where((t) => t.id.equals(carded.id))).getSingle();
    // UTC midnight of the date: a synced device in another zone reads the
    // same day back.
    expect(row.cardLastDive, DateTime.utc(2026, 10, 3).millisecondsSinceEpoch);
  });

  test('every buddy lookup carries the card fields, so an update through '
      'one keeps them', () async {
    final repo = BuddyRepository();
    // No diver yet, as a buddy from an older import can be.
    await repo.createBuddy(carded);

    final found = await repo.findOrCreateByName('Sam Rivera');
    expect(found.cardId, 'diver-sam');
    expect(found.socialHandle, '@samdives');
    final searched = (await repo.searchBuddies('sam')).single;
    expect(searched.cardDiveCount, 118);

    // What a dive import does with a buddy that has no diver.
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.updateBuddy(found.copyWith(diverId: 'me'));
    final read = (await repo.getBuddyById(carded.id))!;
    expect(read.cardId, 'diver-sam');
    expect(read.socialHandle, '@samdives');
    expect(read.cardLastDive, DateTime(2026, 10, 3));
  });

  test('clearPhoto and clearLinkedDiver keep the card fields', () {
    expect(carded.clearPhoto().cardDiveCount, 118);
    expect(carded.clearLinkedDiver().cardId, 'diver-sam');
  });
}
