import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

import '../../../helpers/test_database.dart';

/// A buddy's country and the ISO code saved beside it (issue #4457).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => DatabaseService.instance.resetForTesting());

  domain.Buddy buddy({String? country, String? countryCode}) => domain.Buddy(
    id: 'b-country-1',
    name: 'Marco',
    country: country,
    countryCode: countryCode,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('a new buddy stores its country and the code read from it', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(buddy(country: 'Italy'));
    final read = await repo.getBuddyById('b-country-1');
    expect(read!.country, 'Italy');
    expect(read.countryCode, 'IT');
  });

  test('a changed country never keeps the old flag', () async {
    final repo = BuddyRepository();
    final created = await repo.createBuddy(buddy(country: 'Italy'));
    final stored = await repo.getBuddyById(created.id);
    // A copy that sets only the country carries the old code with it.
    await repo.updateBuddy(stored!.copyWith(country: 'Malta'));
    final read = await repo.getBuddyById(created.id);
    expect(read!.country, 'Malta');
    expect(read.countryCode, 'MT');
  });

  test('a blank country is stored as none, with no code', () async {
    final repo = BuddyRepository();
    final created = await repo.createBuddy(buddy(country: 'Italy'));
    final stored = await repo.getBuddyById(created.id);
    await repo.updateBuddy(stored!.copyWith(country: '  '));
    final read = await repo.getBuddyById(created.id);
    expect(read!.country, isNull);
    expect(read.countryCode, isNull);
  });

  test('clearing the country clears the code', () async {
    final repo = BuddyRepository();
    final created = await repo.createBuddy(buddy(country: 'Italy'));
    final stored = await repo.getBuddyById(created.id);
    await repo.updateBuddy(stored!.copyWith(clearCountry: true));
    final read = await repo.getBuddyById(created.id);
    expect(read!.country, isNull);
    expect(read.countryCode, isNull);
  });

  test('text that names no country is kept, with no code', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(buddy(country: 'Atlantis'));
    final read = await repo.getBuddyById('b-country-1');
    expect(read!.country, 'Atlantis');
    expect(read.countryCode, isNull);
  });

  test('a partial write that sets only the country derives the code', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(buddy(country: 'Italy'));
    await repo.updateFields(
      'b-country-1',
      const BuddiesCompanion(country: Value('Japan')),
    );
    final read = await repo.getBuddyById('b-country-1');
    expect(read!.country, 'Japan');
    expect(read.countryCode, 'JP');
  });

  test('a row without the columns, as an older peer sends it, hydrates', () {
    final row = Buddy.fromJson({
      'id': 'b-old',
      'name': 'Marco',
      'notes': '',
      'isFavorite': false,
      'excludedFromRankings': false,
      'createdAt': 0,
      'updatedAt': 0,
    });
    expect(row.country, isNull);
    expect(row.countryCode, isNull);
  });

  group('search', () {
    test('the buddy picker search finds a buddy by country', () async {
      final repo = BuddyRepository();
      await repo.createBuddy(buddy(country: 'Italy'));
      final found = await repo.getAllBuddiesWithDiveCount(query: 'ital');
      expect([for (final b in found) b.buddy.id], ['b-country-1']);
    });

    test('searchBuddies finds a buddy by country', () async {
      final repo = BuddyRepository();
      await repo.createBuddy(buddy(country: 'Italy'));
      final found = await repo.searchBuddies('ital');
      expect([for (final b in found) b.id], ['b-country-1']);
    });
  });

  test('a merge that changes the country re-reads the code', () async {
    final repo = BuddyRepository();
    final survivor = await repo.createBuddy(buddy(country: 'Italy'));
    final duplicate = await repo.createBuddy(
      domain.Buddy(
        id: 'b-country-2',
        name: 'M.',
        country: 'Malta',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final stored = await repo.getBuddyById(survivor.id);
    // A merged buddy built by copying the survivor carries its old code.
    await BuddyMergeRepository().mergeBuddies(
      mergedBuddy: stored!.copyWith(country: 'Malta'),
      buddyIds: [survivor.id, duplicate.id],
    );
    final read = await repo.getBuddyById(survivor.id);
    expect(read!.country, 'Malta');
    expect(read.countryCode, 'MT');
  });

  test('undoing a merge brings back each buddy country', () async {
    final repo = BuddyRepository();
    final survivor = await repo.createBuddy(buddy(country: 'Italy'));
    final duplicate = await repo.createBuddy(
      domain.Buddy(
        id: 'b-country-2',
        name: 'M.',
        country: 'Malta',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final stored = await repo.getBuddyById(survivor.id);
    final result = await BuddyMergeRepository().mergeBuddies(
      mergedBuddy: stored!.copyWith(country: 'Malta'),
      buddyIds: [survivor.id, duplicate.id],
    );
    await BuddyMergeRepository().undoMerge(result!.snapshot!);

    final back = await repo.getBuddyById(survivor.id);
    expect(back!.country, 'Italy');
    expect(back.countryCode, 'IT');
    final restored = await repo.getBuddyById(duplicate.id);
    expect(restored!.country, 'Malta');
    expect(restored.countryCode, 'MT');
  });

  test('the countries in use are listed once each, blanks left out', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(buddy(country: 'Italy'));
    for (final (id, country) in [
      ('b2', 'Italy'),
      ('b3', null),
      ('b4', 'Malta'),
    ]) {
      await repo.createBuddy(
        domain.Buddy(
          id: id,
          name: id,
          country: country,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    }
    expect(await repo.getUsedCountries(), unorderedEquals(['Italy', 'Malta']));
  });

  test(
    'a partial write that sets the country and a code keeps the code',
    () async {
      final repo = BuddyRepository();
      await repo.createBuddy(buddy(country: 'Italy'));
      await repo.updateFields(
        'b-country-1',
        const BuddiesCompanion(
          country: Value('Korea'),
          countryCode: Value('KR'),
        ),
      );
      final read = await repo.getBuddyById('b-country-1');
      expect(read!.country, 'Korea');
      expect(read.countryCode, 'KR');
    },
  );
}
