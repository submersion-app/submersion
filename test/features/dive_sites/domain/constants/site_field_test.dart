import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative SiteWithCount entity for adapter tests.
  const testSite = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    description: 'Classic dive spot',
    country: 'Malta',
    region: 'Gozo',
    location: GeoPoint(36.04270, 14.19827),
    maxDepth: 50.0,
    minDepth: 5.0,
    altitude: 200.0,
    difficulty: SiteDifficulty.advanced,
    rating: 4.5,
    notes: 'Great site',
    hazards: 'Strong current',
    mooringNumber: '7',
    conditions: SiteConditions(
      waterType: 'salt',
      typicalVisibility: '20m',
      typicalCurrent: 'moderate',
      bestSeason: 'summer',
      entryType: 'shore',
    ),
  );

  const testEntity = (site: testSite, diveCount: 12);

  group('SiteFieldAdapter.allFields', () {
    test('has expected count matching SiteField.values', () {
      expect(
        SiteFieldAdapter.instance.allFields.length,
        equals(SiteField.values.length),
      );
    });

    test('contains all SiteField values', () {
      expect(
        SiteFieldAdapter.instance.allFields,
        containsAll(SiteField.values),
      );
    });
  });

  group('SiteFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          SiteField.siteName,
          SiteField.location,
          SiteField.country,
          SiteField.region,
          SiteField.diveCount,
        ]),
      );
    });

    test('groups depth fields together', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['depth'],
        containsAll([
          SiteField.maxDepth,
          SiteField.minDepth,
          SiteField.altitude,
        ]),
      );
    });

    test('groups coordinate fields together', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['coordinates'],
        containsAll([SiteField.latitude, SiteField.longitude]),
      );
    });

    test('covers all SiteField values across categories', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(SiteField.values.length));
    });
  });

  group('SiteFieldAdapter.extractValue', () {
    final adapter = SiteFieldAdapter.instance;

    test('returns site name', () {
      expect(
        adapter.extractValue(SiteField.siteName, testEntity),
        equals('Blue Hole'),
      );
    });

    test('returns country', () {
      expect(
        adapter.extractValue(SiteField.country, testEntity),
        equals('Malta'),
      );
    });

    test('returns region', () {
      expect(
        adapter.extractValue(SiteField.region, testEntity),
        equals('Gozo'),
      );
    });

    test('returns dive count', () {
      expect(adapter.extractValue(SiteField.diveCount, testEntity), equals(12));
    });

    test('returns maxDepth', () {
      expect(
        adapter.extractValue(SiteField.maxDepth, testEntity),
        equals(50.0),
      );
    });

    test('returns minDepth', () {
      expect(adapter.extractValue(SiteField.minDepth, testEntity), equals(5.0));
    });

    test('returns altitude', () {
      expect(
        adapter.extractValue(SiteField.altitude, testEntity),
        equals(200.0),
      );
    });

    test('returns latitude from GeoPoint', () {
      expect(
        adapter.extractValue(SiteField.latitude, testEntity),
        closeTo(36.04270, 0.00001),
      );
    });

    test('returns longitude from GeoPoint', () {
      expect(
        adapter.extractValue(SiteField.longitude, testEntity),
        closeTo(14.19827, 0.00001),
      );
    });

    test('returns difficulty enum', () {
      expect(
        adapter.extractValue(SiteField.difficulty, testEntity),
        equals(SiteDifficulty.advanced),
      );
    });

    test('returns rating', () {
      expect(adapter.extractValue(SiteField.rating, testEntity), equals(4.5));
    });

    test('returns waterType from conditions', () {
      expect(
        adapter.extractValue(SiteField.waterType, testEntity),
        equals('salt'),
      );
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(SiteField.notes, testEntity),
        equals('Great site'),
      );
    });

    test('returns null for notes when empty', () {
      final emptyNotesSite = testSite.copyWith(notes: '');
      final entity = (site: emptyNotesSite, diveCount: 0);
      expect(adapter.extractValue(SiteField.notes, entity), isNull);
    });

    test('returns null for location when site has no GeoPoint', () {
      const noLocSite = DiveSite(id: 'no-loc', name: 'No Loc');
      const entity = (site: noLocSite, diveCount: 0);
      expect(adapter.extractValue(SiteField.latitude, entity), isNull);
      expect(adapter.extractValue(SiteField.longitude, entity), isNull);
    });
  });

  group('SiteFieldAdapter.formatValue', () {
    final adapter = SiteFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(SiteField.siteName, null, units),
        equals('--'),
      );
    });

    test('formats depth in meters (default settings)', () {
      final formatted = adapter.formatValue(SiteField.maxDepth, 30.0, units);
      expect(formatted, equals('30m'));
    });

    test('formats altitude as integer meters', () {
      final formatted = adapter.formatValue(SiteField.altitude, 200.0, units);
      expect(formatted, equals('200 m'));
    });

    test('formats dive count as integer string', () {
      expect(adapter.formatValue(SiteField.diveCount, 7, units), equals('7'));
    });

    test('formats difficulty displayName', () {
      expect(
        adapter.formatValue(
          SiteField.difficulty,
          SiteDifficulty.advanced,
          units,
        ),
        equals('Advanced'),
      );
    });

    test('formats rating with one decimal place', () {
      expect(adapter.formatValue(SiteField.rating, 4.5, units), equals('4.5'));
    });

    test('formats latitude/longitude with 5 decimal places', () {
      expect(
        adapter.formatValue(SiteField.latitude, 36.04270, units),
        equals('36.04270'),
      );
    });

    test('returns string values for text fields', () {
      expect(
        adapter.formatValue(SiteField.country, 'Malta', units),
        equals('Malta'),
      );
    });
  });

  group('SiteFieldAdapter.fieldFromName', () {
    final adapter = SiteFieldAdapter.instance;

    test('resolves siteName', () {
      expect(adapter.fieldFromName('siteName'), equals(SiteField.siteName));
    });

    test('resolves maxDepth', () {
      expect(adapter.fieldFromName('maxDepth'), equals(SiteField.maxDepth));
    });

    test('resolves latitude', () {
      expect(adapter.fieldFromName('latitude'), equals(SiteField.latitude));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });
}
