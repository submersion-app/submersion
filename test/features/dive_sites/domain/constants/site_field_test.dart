import 'package:flutter/material.dart';
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

  group('SiteField.displayName', () {
    test('every enum value has a non-empty displayName', () {
      for (final field in SiteField.values) {
        expect(
          field.displayName.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a non-empty displayName',
        );
      }
    });

    test('returns expected display names for specific fields', () {
      expect(SiteField.siteName.displayName, equals('Name'));
      expect(SiteField.location.displayName, equals('Location'));
      expect(SiteField.country.displayName, equals('Country'));
      expect(SiteField.region.displayName, equals('Region'));
      expect(SiteField.diveCount.displayName, equals('Dive Count'));
      expect(SiteField.maxDepth.displayName, equals('Max Depth'));
      expect(SiteField.minDepth.displayName, equals('Min Depth'));
      expect(SiteField.altitude.displayName, equals('Altitude'));
      expect(SiteField.waterType.displayName, equals('Water Type'));
      expect(
        SiteField.typicalVisibility.displayName,
        equals('Typical Visibility'),
      );
      expect(SiteField.typicalCurrent.displayName, equals('Typical Current'));
      expect(SiteField.difficulty.displayName, equals('Difficulty'));
      expect(SiteField.entryType.displayName, equals('Entry Type'));
      expect(SiteField.bestSeason.displayName, equals('Best Season'));
      expect(SiteField.mooringNumber.displayName, equals('Mooring Number'));
      expect(SiteField.hazards.displayName, equals('Hazards'));
      expect(SiteField.rating.displayName, equals('Rating'));
      expect(SiteField.notes.displayName, equals('Notes'));
      expect(SiteField.latitude.displayName, equals('Latitude'));
      expect(SiteField.longitude.displayName, equals('Longitude'));
    });
  });

  group('SiteField.shortLabel', () {
    test('every enum value has a non-empty shortLabel', () {
      for (final field in SiteField.values) {
        expect(
          field.shortLabel.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a non-empty shortLabel',
        );
      }
    });

    test('returns expected short labels for specific fields', () {
      expect(SiteField.siteName.shortLabel, equals('Name'));
      expect(SiteField.location.shortLabel, equals('Location'));
      expect(SiteField.country.shortLabel, equals('Country'));
      expect(SiteField.region.shortLabel, equals('Region'));
      expect(SiteField.diveCount.shortLabel, equals('Dives'));
      expect(SiteField.maxDepth.shortLabel, equals('Max D'));
      expect(SiteField.minDepth.shortLabel, equals('Min D'));
      expect(SiteField.altitude.shortLabel, equals('Alt'));
      expect(SiteField.waterType.shortLabel, equals('Water'));
      expect(SiteField.typicalVisibility.shortLabel, equals('Vis'));
      expect(SiteField.typicalCurrent.shortLabel, equals('Current'));
      expect(SiteField.difficulty.shortLabel, equals('Diff'));
      expect(SiteField.entryType.shortLabel, equals('Entry'));
      expect(SiteField.bestSeason.shortLabel, equals('Season'));
      expect(SiteField.mooringNumber.shortLabel, equals('Mooring'));
      expect(SiteField.hazards.shortLabel, equals('Hazards'));
      expect(SiteField.rating.shortLabel, equals('Rating'));
      expect(SiteField.notes.shortLabel, equals('Notes'));
      expect(SiteField.latitude.shortLabel, equals('Lat'));
      expect(SiteField.longitude.shortLabel, equals('Lon'));
    });
  });

  group('SiteField.icon', () {
    test('every enum value has a non-null icon', () {
      for (final field in SiteField.values) {
        expect(
          field.icon,
          isNotNull,
          reason: '${field.name} should have a non-null icon',
        );
      }
    });

    test('returns expected icons for specific fields', () {
      expect(SiteField.siteName.icon, equals(Icons.place));
      expect(SiteField.location.icon, equals(Icons.location_on));
      expect(SiteField.country.icon, equals(Icons.flag));
      expect(SiteField.region.icon, equals(Icons.map));
      expect(SiteField.diveCount.icon, equals(Icons.water));
      expect(SiteField.maxDepth.icon, equals(Icons.vertical_align_bottom));
      expect(SiteField.minDepth.icon, equals(Icons.vertical_align_top));
      expect(SiteField.altitude.icon, equals(Icons.terrain));
      expect(SiteField.waterType.icon, equals(Icons.water_drop));
      expect(SiteField.typicalVisibility.icon, equals(Icons.visibility));
      expect(SiteField.typicalCurrent.icon, equals(Icons.air));
      expect(SiteField.difficulty.icon, equals(Icons.signal_cellular_alt));
      expect(SiteField.entryType.icon, equals(Icons.login));
      expect(SiteField.bestSeason.icon, equals(Icons.calendar_month));
      expect(SiteField.mooringNumber.icon, equals(Icons.anchor));
      expect(SiteField.hazards.icon, equals(Icons.warning));
      expect(SiteField.rating.icon, equals(Icons.star));
      expect(SiteField.notes.icon, equals(Icons.notes));
      expect(SiteField.latitude.icon, equals(Icons.my_location));
      expect(SiteField.longitude.icon, equals(Icons.my_location));
    });
  });

  group('SiteField.categoryName', () {
    test('every enum value has a non-empty categoryName', () {
      for (final field in SiteField.values) {
        expect(
          field.categoryName.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a non-empty categoryName',
        );
      }
    });

    test('core fields return core category', () {
      for (final field in [
        SiteField.siteName,
        SiteField.location,
        SiteField.country,
        SiteField.region,
        SiteField.diveCount,
      ]) {
        expect(
          field.categoryName,
          equals('core'),
          reason: '${field.name} should be in core category',
        );
      }
    });

    test('depth fields return depth category', () {
      for (final field in [
        SiteField.maxDepth,
        SiteField.minDepth,
        SiteField.altitude,
      ]) {
        expect(
          field.categoryName,
          equals('depth'),
          reason: '${field.name} should be in depth category',
        );
      }
    });

    test('conditions fields return conditions category', () {
      for (final field in [
        SiteField.waterType,
        SiteField.typicalVisibility,
        SiteField.typicalCurrent,
        SiteField.difficulty,
        SiteField.entryType,
        SiteField.bestSeason,
      ]) {
        expect(
          field.categoryName,
          equals('conditions'),
          reason: '${field.name} should be in conditions category',
        );
      }
    });

    test('details fields return details category', () {
      for (final field in [
        SiteField.mooringNumber,
        SiteField.hazards,
        SiteField.rating,
        SiteField.notes,
      ]) {
        expect(
          field.categoryName,
          equals('details'),
          reason: '${field.name} should be in details category',
        );
      }
    });

    test('coordinate fields return coordinates category', () {
      for (final field in [SiteField.latitude, SiteField.longitude]) {
        expect(
          field.categoryName,
          equals('coordinates'),
          reason: '${field.name} should be in coordinates category',
        );
      }
    });
  });

  group('SiteField.isRightAligned', () {
    test('numeric fields are right-aligned', () {
      final rightAlignedFields = [
        SiteField.diveCount,
        SiteField.maxDepth,
        SiteField.minDepth,
        SiteField.altitude,
        SiteField.rating,
        SiteField.latitude,
        SiteField.longitude,
      ];
      for (final field in rightAlignedFields) {
        expect(
          field.isRightAligned,
          isTrue,
          reason: '${field.name} should be right-aligned',
        );
      }
    });

    test('text fields are not right-aligned', () {
      final leftAlignedFields = [
        SiteField.siteName,
        SiteField.location,
        SiteField.country,
        SiteField.region,
        SiteField.waterType,
        SiteField.typicalVisibility,
        SiteField.typicalCurrent,
        SiteField.difficulty,
        SiteField.entryType,
        SiteField.bestSeason,
        SiteField.mooringNumber,
        SiteField.hazards,
        SiteField.notes,
      ];
      for (final field in leftAlignedFields) {
        expect(
          field.isRightAligned,
          isFalse,
          reason: '${field.name} should not be right-aligned',
        );
      }
    });

    test('covers all enum values', () {
      // Verify every value is covered by either right or left aligned
      final rightAligned = SiteField.values
          .where((f) => f.isRightAligned)
          .toSet();
      final leftAligned = SiteField.values
          .where((f) => !f.isRightAligned)
          .toSet();
      expect(
        rightAligned.length + leftAligned.length,
        equals(SiteField.values.length),
      );
    });
  });

  group('SiteField.defaultWidth', () {
    test('every enum value has a positive defaultWidth', () {
      for (final field in SiteField.values) {
        expect(
          field.defaultWidth,
          greaterThan(0),
          reason: '${field.name} should have a positive defaultWidth',
        );
      }
    });
  });

  group('SiteField.minWidth', () {
    test('every enum value has minWidth <= defaultWidth', () {
      for (final field in SiteField.values) {
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: '${field.name} minWidth should be <= defaultWidth',
        );
      }
    });
  });

  group('SiteField.sortable', () {
    test('sortable fields include expected values', () {
      final sortableFields = [
        SiteField.siteName,
        SiteField.country,
        SiteField.region,
        SiteField.diveCount,
        SiteField.maxDepth,
        SiteField.minDepth,
        SiteField.altitude,
        SiteField.difficulty,
        SiteField.rating,
        SiteField.latitude,
        SiteField.longitude,
      ];
      for (final field in sortableFields) {
        expect(
          field.sortable,
          isTrue,
          reason: '${field.name} should be sortable',
        );
      }
    });

    test('non-sortable fields include expected values', () {
      final nonSortableFields = [
        SiteField.location,
        SiteField.waterType,
        SiteField.typicalVisibility,
        SiteField.typicalCurrent,
        SiteField.entryType,
        SiteField.bestSeason,
        SiteField.mooringNumber,
        SiteField.hazards,
        SiteField.notes,
      ];
      for (final field in nonSortableFields) {
        expect(
          field.sortable,
          isFalse,
          reason: '${field.name} should not be sortable',
        );
      }
    });
  });

  group('SiteFieldAdapter.fieldsByCategory (remaining categories)', () {
    test('groups conditions fields together', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['conditions'],
        containsAll([
          SiteField.waterType,
          SiteField.typicalVisibility,
          SiteField.typicalCurrent,
          SiteField.difficulty,
          SiteField.entryType,
          SiteField.bestSeason,
        ]),
      );
    });

    test('groups details fields together', () {
      final byCategory = SiteFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['details'],
        containsAll([
          SiteField.mooringNumber,
          SiteField.hazards,
          SiteField.rating,
          SiteField.notes,
        ]),
      );
    });
  });

  group('SiteFieldAdapter.extractValue (remaining fields)', () {
    final adapter = SiteFieldAdapter.instance;

    test('returns location string', () {
      expect(
        adapter.extractValue(SiteField.location, testEntity),
        equals('Gozo, Malta'),
      );
    });

    test('returns typicalVisibility from conditions', () {
      expect(
        adapter.extractValue(SiteField.typicalVisibility, testEntity),
        equals('20m'),
      );
    });

    test('returns typicalCurrent from conditions', () {
      expect(
        adapter.extractValue(SiteField.typicalCurrent, testEntity),
        equals('moderate'),
      );
    });

    test('returns entryType from conditions', () {
      expect(
        adapter.extractValue(SiteField.entryType, testEntity),
        equals('shore'),
      );
    });

    test('returns bestSeason from conditions', () {
      expect(
        adapter.extractValue(SiteField.bestSeason, testEntity),
        equals('summer'),
      );
    });

    test('returns mooringNumber', () {
      expect(
        adapter.extractValue(SiteField.mooringNumber, testEntity),
        equals('7'),
      );
    });

    test('returns hazards', () {
      expect(
        adapter.extractValue(SiteField.hazards, testEntity),
        equals('Strong current'),
      );
    });

    test('returns description', () {
      // description field is not a SiteField; verify location string instead
      expect(
        adapter.extractValue(SiteField.location, testEntity),
        equals('Gozo, Malta'),
      );
    });

    test('returns null for conditions fields when conditions is null', () {
      const noCondSite = DiveSite(id: 'no-cond', name: 'No Conditions');
      const entity = (site: noCondSite, diveCount: 0);
      expect(adapter.extractValue(SiteField.waterType, entity), isNull);
      expect(adapter.extractValue(SiteField.typicalVisibility, entity), isNull);
      expect(adapter.extractValue(SiteField.typicalCurrent, entity), isNull);
      expect(adapter.extractValue(SiteField.entryType, entity), isNull);
      expect(adapter.extractValue(SiteField.bestSeason, entity), isNull);
    });

    test('returns null for difficulty when not set', () {
      const noDiffSite = DiveSite(id: 'no-diff', name: 'No Difficulty');
      const entity = (site: noDiffSite, diveCount: 0);
      expect(adapter.extractValue(SiteField.difficulty, entity), isNull);
    });

    test('returns null for mooringNumber when not set', () {
      const site = DiveSite(id: 'no-mooring', name: 'No Mooring');
      const entity = (site: site, diveCount: 0);
      expect(adapter.extractValue(SiteField.mooringNumber, entity), isNull);
    });

    test('returns null for hazards when not set', () {
      const site = DiveSite(id: 'no-hazards', name: 'No Hazards');
      const entity = (site: site, diveCount: 0);
      expect(adapter.extractValue(SiteField.hazards, entity), isNull);
    });
  });

  group('SiteFieldAdapter.formatValue (remaining fields)', () {
    final adapter = SiteFieldAdapter.instance;

    test('formats location as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.location, 'Gozo, Malta', units),
        equals('Gozo, Malta'),
      );
    });

    test('formats waterType as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.waterType, 'salt', units),
        equals('salt'),
      );
    });

    test('formats typicalVisibility as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.typicalVisibility, '20m', units),
        equals('20m'),
      );
    });

    test('formats typicalCurrent as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.typicalCurrent, 'moderate', units),
        equals('moderate'),
      );
    });

    test('formats entryType as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.entryType, 'shore', units),
        equals('shore'),
      );
    });

    test('formats bestSeason as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.bestSeason, 'summer', units),
        equals('summer'),
      );
    });

    test('formats mooringNumber as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.mooringNumber, '7', units),
        equals('7'),
      );
    });

    test('formats hazards as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.hazards, 'Strong current', units),
        equals('Strong current'),
      );
    });

    test('formats notes as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.notes, 'Great site', units),
        equals('Great site'),
      );
    });

    test('formats region as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.region, 'Gozo', units),
        equals('Gozo'),
      );
    });

    test('formats siteName as string passthrough', () {
      expect(
        adapter.formatValue(SiteField.siteName, 'Blue Hole', units),
        equals('Blue Hole'),
      );
    });

    test('formats minDepth in meters', () {
      final formatted = adapter.formatValue(SiteField.minDepth, 5.0, units);
      expect(formatted, equals('5m'));
    });

    test('formats longitude with 5 decimal places', () {
      expect(
        adapter.formatValue(SiteField.longitude, 14.19827, units),
        equals('14.19827'),
      );
    });

    test('formats difficulty beginner displayName', () {
      expect(
        adapter.formatValue(
          SiteField.difficulty,
          SiteDifficulty.beginner,
          units,
        ),
        equals('Beginner'),
      );
    });

    test('formats difficulty intermediate displayName', () {
      expect(
        adapter.formatValue(
          SiteField.difficulty,
          SiteDifficulty.intermediate,
          units,
        ),
        equals('Intermediate'),
      );
    });

    test('formats difficulty technical displayName', () {
      expect(
        adapter.formatValue(
          SiteField.difficulty,
          SiteDifficulty.technical,
          units,
        ),
        equals('Technical'),
      );
    });

    test('returns -- for null difficulty', () {
      expect(
        adapter.formatValue(SiteField.difficulty, null, units),
        equals('--'),
      );
    });

    test('returns -- for null waterType', () {
      expect(
        adapter.formatValue(SiteField.waterType, null, units),
        equals('--'),
      );
    });

    test('returns -- for null typicalVisibility', () {
      expect(
        adapter.formatValue(SiteField.typicalVisibility, null, units),
        equals('--'),
      );
    });

    test('returns -- for null bestSeason', () {
      expect(
        adapter.formatValue(SiteField.bestSeason, null, units),
        equals('--'),
      );
    });
  });
}
