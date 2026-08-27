import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';

void main() {
  SpeciesSightingRecord record() => SpeciesSightingRecord(
    sightingId: 'sg1',
    diveId: 'd1',
    diveNumber: 42,
    diveDateTime: DateTime(2024, 1, 15, 9, 30),
    siteId: 'site1',
    siteName: 'Blue Hole',
    maxDepthMeters: 18.5,
    count: 3,
    notes: 'Juvenile under the ledge',
  );

  test('two records with the same values are equal', () {
    expect(record(), equals(record()));
  });

  test('copyWith replaces only the given fields', () {
    final copy = record().copyWith(count: 1, notes: '');

    expect(copy.count, 1);
    expect(copy.notes, '');
    expect(copy.diveNumber, 42);
    expect(copy.siteName, 'Blue Hole');
    expect(copy.maxDepthMeters, 18.5);
  });

  test('site and depth are optional', () {
    final record = SpeciesSightingRecord(
      sightingId: 'sg1',
      diveId: 'd1',
      diveDateTime: DateTime(2024, 1, 1),
      count: 1,
      notes: '',
    );
    expect(record.siteId, isNull);
    expect(record.siteName, isNull);
    expect(record.maxDepthMeters, isNull);
    expect(record.diveNumber, isNull);
  });
}
