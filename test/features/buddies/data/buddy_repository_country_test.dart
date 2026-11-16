import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
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
}
