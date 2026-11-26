import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/domain/species_rarity.dart';

import 'species_test_entries.dart';

void main() {
  final now = DateTime(2026, 11, 25, 12);

  test('new beats seen once', () {
    final e = seenEntry('a', dives: 1, first: DateTime.utc(2026, 11, 15));
    expect(rarityFor(e, now: now), SpeciesRarity.newSpecies);
  });

  test('89 days is new, 91 is not', () {
    final at89 = seenEntry('a', first: DateTime.utc(2026, 8, 28, 12));
    final at91 = seenEntry('b', first: DateTime.utc(2026, 8, 26, 12));
    expect(rarityFor(at89, now: now), SpeciesRarity.newSpecies);
    expect(rarityFor(at91, now: now), isNull);
  });

  test('seen once', () {
    final e = seenEntry('a', dives: 1, first: DateTime.utc(2025, 3, 1));
    expect(rarityFor(e, now: now), SpeciesRarity.seenOnce);
  });

  test('731 days since last seen is not seen lately, 729 is not', () {
    final old = seenEntry(
      'a',
      first: DateTime.utc(2020, 1, 1),
      last: DateTime.utc(2024, 11, 24, 12),
    );
    final recent = seenEntry(
      'b',
      first: DateTime.utc(2020, 1, 1),
      last: DateTime.utc(2024, 11, 26, 12),
    );
    expect(rarityFor(old, now: now), SpeciesRarity.notSeenLately);
    expect(rarityFor(recent, now: now), isNull);
  });

  test('mastered only when nothing else applies', () {
    final plain = seenEntry('a', first: DateTime.utc(2025, 1, 1));
    final once = seenEntry('b', dives: 1, first: DateTime.utc(2025, 1, 1));
    expect(rarityFor(plain, now: now, practiceBox: 5), SpeciesRarity.mastered);
    expect(rarityFor(plain, now: now, practiceBox: 4), isNull);
    expect(rarityFor(once, now: now, practiceBox: 5), SpeciesRarity.seenOnce);
  });

  test('null for an ordinary species', () {
    final e = seenEntry('a', dives: 4, first: DateTime.utc(2025, 1, 1));
    expect(rarityFor(e, now: now), isNull);
  });
}
