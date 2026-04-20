import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('DiveSite.isShared', () {
    test('defaults to false', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.isShared, isFalse);
    });

    test('copyWith sets isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      final shared = site.copyWith(isShared: true);
      expect(shared.isShared, isTrue);
      expect(site.isShared, isFalse);
    });

    test('props include isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site == site.copyWith(isShared: true), isFalse);
    });
  });

  group('SiteDifficulty.displayName', () {
    test('maps each difficulty to its display label', () {
      expect(SiteDifficulty.beginner.displayName, equals('Beginner'));
      expect(SiteDifficulty.intermediate.displayName, equals('Intermediate'));
      expect(SiteDifficulty.advanced.displayName, equals('Advanced'));
      expect(SiteDifficulty.technical.displayName, equals('Technical'));
    });
  });

  group('SiteDifficulty.fromString', () {
    test('returns null for null input', () {
      expect(SiteDifficulty.fromString(null), isNull);
    });

    test('parses valid names case-insensitively', () {
      expect(SiteDifficulty.fromString('beginner'), SiteDifficulty.beginner);
      expect(SiteDifficulty.fromString('ADVANCED'), SiteDifficulty.advanced);
      expect(SiteDifficulty.fromString('Technical'), SiteDifficulty.technical);
    });

    test('returns null for unknown values', () {
      expect(SiteDifficulty.fromString('expert'), isNull);
      expect(SiteDifficulty.fromString(''), isNull);
    });
  });

  group('DiveSite.locationString', () {
    test('returns empty string when region and country are null', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.locationString, isEmpty);
    });

    test('returns only region when country is missing', () {
      const site = DiveSite(id: 's1', name: 'Reef', region: 'Cozumel');
      expect(site.locationString, equals('Cozumel'));
    });

    test('returns only country when region is missing', () {
      const site = DiveSite(id: 's1', name: 'Reef', country: 'Mexico');
      expect(site.locationString, equals('Mexico'));
    });

    test('joins region, country with ", " when both present', () {
      const site = DiveSite(
        id: 's1',
        name: 'Reef',
        region: 'Cozumel',
        country: 'Mexico',
      );
      expect(site.locationString, equals('Cozumel, Mexico'));
    });

    test('skips empty-string fields', () {
      const site = DiveSite(
        id: 's1',
        name: 'Reef',
        region: '',
        country: 'Mexico',
      );
      expect(site.locationString, equals('Mexico'));
    });
  });

  group('DiveSite.hasCoordinates', () {
    test('is false when location is null', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.hasCoordinates, isFalse);
    });

    test('is true when location is set', () {
      const site = DiveSite(
        id: 's1',
        name: 'Reef',
        location: GeoPoint(10.0, 20.0),
      );
      expect(site.hasCoordinates, isTrue);
    });
  });

  group('DiveSite.depthRange', () {
    test('returns null when both depths are null', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.depthRange, isNull);
    });

    test('returns min-max range when both depths are set', () {
      const site = DiveSite(
        id: 's1',
        name: 'Reef',
        minDepth: 5.0,
        maxDepth: 30.0,
      );
      expect(site.depthRange, equals('5-30m'));
    });

    test('returns min+ when only minDepth is set', () {
      const site = DiveSite(id: 's1', name: 'Reef', minDepth: 18.0);
      expect(site.depthRange, equals('18m+'));
    });

    test('returns "up to X" when only maxDepth is set', () {
      const site = DiveSite(id: 's1', name: 'Reef', maxDepth: 40.0);
      expect(site.depthRange, equals('up to 40m'));
    });
  });

  group('DiveSite.copyWith', () {
    const base = DiveSite(
      id: 's1',
      name: 'Reef',
      description: 'desc',
      country: 'MX',
      region: 'Cozumel',
      rating: 4.5,
    );

    test('preserves existing values when no args given', () {
      final copy = base.copyWith();
      expect(copy, equals(base));
    });

    test('replaces scalar fields', () {
      final copy = base.copyWith(
        name: 'New Reef',
        description: 'new desc',
        country: 'US',
        rating: 3.0,
      );
      expect(copy.name, equals('New Reef'));
      expect(copy.description, equals('new desc'));
      expect(copy.country, equals('US'));
      expect(copy.rating, equals(3.0));
      // Unchanged
      expect(copy.region, equals('Cozumel'));
    });

    test('replaces photoIds and conditions', () {
      final copy = base.copyWith(
        photoIds: ['p1', 'p2'],
        conditions: const SiteConditions(waterType: 'salt'),
      );
      expect(copy.photoIds, equals(['p1', 'p2']));
      expect(copy.conditions?.waterType, equals('salt'));
    });
  });

  group('GeoPoint', () {
    test('equality by latitude and longitude', () {
      const p1 = GeoPoint(10.12345, 20.98765);
      const p2 = GeoPoint(10.12345, 20.98765);
      expect(p1, equals(p2));
    });

    test('toString formats with 6 decimal places', () {
      const p = GeoPoint(10.0, -20.5);
      expect(p.toString(), equals('10.000000, -20.500000'));
    });
  });

  group('SiteConditions', () {
    test('equality by all fields', () {
      const a = SiteConditions(
        waterType: 'salt',
        typicalVisibility: '20m',
        typicalCurrent: 'mild',
        bestSeason: 'summer',
        minTemp: 22.0,
        maxTemp: 28.0,
        entryType: 'shore',
      );
      const b = SiteConditions(
        waterType: 'salt',
        typicalVisibility: '20m',
        typicalCurrent: 'mild',
        bestSeason: 'summer',
        minTemp: 22.0,
        maxTemp: 28.0,
        entryType: 'shore',
      );
      expect(a, equals(b));
    });

    test('distinguishes objects by field differences', () {
      const a = SiteConditions(waterType: 'salt');
      const b = SiteConditions(waterType: 'fresh');
      expect(a == b, isFalse);
    });
  });
}
