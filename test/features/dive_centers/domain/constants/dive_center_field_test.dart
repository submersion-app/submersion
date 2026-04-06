import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative DiveCenterRow entity for adapter tests.
  final testCenter = DiveCenter(
    id: 'center-1',
    name: 'Blue Water Divers',
    city: 'Valletta',
    country: 'Malta',
    stateProvince: 'South Eastern',
    street: '123 Harbor Rd',
    postalCode: 'VLT 1234',
    phone: '+356 1234 5678',
    email: 'info@bluewater.mt',
    website: 'https://bluewater.mt',
    affiliations: const ['PADI', 'SSI'],
    rating: 4.7,
    latitude: 35.89780,
    longitude: 14.51220,
    notes: 'Great dive center',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
  final testEntity = (center: testCenter, diveCount: 42);

  group('DiveCenterFieldAdapter.allFields', () {
    test('has expected count matching DiveCenterField.values', () {
      expect(
        DiveCenterFieldAdapter.instance.allFields.length,
        equals(DiveCenterField.values.length),
      );
    });

    test('contains all DiveCenterField values', () {
      expect(
        DiveCenterFieldAdapter.instance.allFields,
        containsAll(DiveCenterField.values),
      );
    });
  });

  group('DiveCenterFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          DiveCenterField.centerName,
          DiveCenterField.city,
          DiveCenterField.country,
          DiveCenterField.diveCount,
        ]),
      );
    });

    test('groups address fields together', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['address'],
        containsAll([
          DiveCenterField.street,
          DiveCenterField.stateProvince,
          DiveCenterField.postalCode,
        ]),
      );
    });

    test('groups contact fields together', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['contact'],
        containsAll([
          DiveCenterField.phone,
          DiveCenterField.email,
          DiveCenterField.website,
        ]),
      );
    });

    test('groups details fields together', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['details'],
        containsAll([
          DiveCenterField.affiliations,
          DiveCenterField.rating,
          DiveCenterField.notes,
        ]),
      );
    });

    test('groups coordinate fields together', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['coordinates'],
        containsAll([DiveCenterField.latitude, DiveCenterField.longitude]),
      );
    });

    test('covers all DiveCenterField values across categories', () {
      final byCategory = DiveCenterFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(DiveCenterField.values.length));
    });
  });

  group('DiveCenterFieldAdapter.extractValue', () {
    final adapter = DiveCenterFieldAdapter.instance;

    test('returns center name', () {
      expect(
        adapter.extractValue(DiveCenterField.centerName, testEntity),
        equals('Blue Water Divers'),
      );
    });

    test('returns city', () {
      expect(
        adapter.extractValue(DiveCenterField.city, testEntity),
        equals('Valletta'),
      );
    });

    test('returns country', () {
      expect(
        adapter.extractValue(DiveCenterField.country, testEntity),
        equals('Malta'),
      );
    });

    test('returns stateProvince', () {
      expect(
        adapter.extractValue(DiveCenterField.stateProvince, testEntity),
        equals('South Eastern'),
      );
    });

    test('returns street', () {
      expect(
        adapter.extractValue(DiveCenterField.street, testEntity),
        equals('123 Harbor Rd'),
      );
    });

    test('returns postalCode', () {
      expect(
        adapter.extractValue(DiveCenterField.postalCode, testEntity),
        equals('VLT 1234'),
      );
    });

    test('returns phone', () {
      expect(
        adapter.extractValue(DiveCenterField.phone, testEntity),
        equals('+356 1234 5678'),
      );
    });

    test('returns email', () {
      expect(
        adapter.extractValue(DiveCenterField.email, testEntity),
        equals('info@bluewater.mt'),
      );
    });

    test('returns website', () {
      expect(
        adapter.extractValue(DiveCenterField.website, testEntity),
        equals('https://bluewater.mt'),
      );
    });

    test('returns affiliations list', () {
      expect(
        adapter.extractValue(DiveCenterField.affiliations, testEntity),
        equals(['PADI', 'SSI']),
      );
    });

    test('returns rating', () {
      expect(
        adapter.extractValue(DiveCenterField.rating, testEntity),
        equals(4.7),
      );
    });

    test('returns latitude', () {
      expect(
        adapter.extractValue(DiveCenterField.latitude, testEntity),
        closeTo(35.89780, 0.00001),
      );
    });

    test('returns longitude', () {
      expect(
        adapter.extractValue(DiveCenterField.longitude, testEntity),
        closeTo(14.51220, 0.00001),
      );
    });

    test('returns dive count', () {
      expect(
        adapter.extractValue(DiveCenterField.diveCount, testEntity),
        equals(42),
      );
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(DiveCenterField.notes, testEntity),
        equals('Great dive center'),
      );
    });

    test('returns null for nullable string fields when not set', () {
      final minimal = DiveCenter(
        id: 'min-1',
        name: 'Minimal Center',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (center: minimal, diveCount: 0);
      expect(adapter.extractValue(DiveCenterField.city, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.country, entity), isNull);
      expect(
        adapter.extractValue(DiveCenterField.stateProvince, entity),
        isNull,
      );
      expect(adapter.extractValue(DiveCenterField.street, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.postalCode, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.phone, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.email, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.website, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.rating, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.latitude, entity), isNull);
      expect(adapter.extractValue(DiveCenterField.longitude, entity), isNull);
    });

    test('returns empty list for affiliations when not set', () {
      final minimal = DiveCenter(
        id: 'min-1',
        name: 'Minimal Center',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final entity = (center: minimal, diveCount: 0);
      expect(
        adapter.extractValue(DiveCenterField.affiliations, entity),
        equals(<String>[]),
      );
    });
  });

  group('DiveCenterFieldAdapter.formatValue', () {
    final adapter = DiveCenterFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(DiveCenterField.centerName, null, units),
        equals('--'),
      );
    });

    test('formats affiliations as comma-separated string', () {
      expect(
        adapter.formatValue(DiveCenterField.affiliations, [
          'PADI',
          'SSI',
        ], units),
        equals('PADI, SSI'),
      );
    });

    test('formats empty affiliations list as --', () {
      expect(
        adapter.formatValue(DiveCenterField.affiliations, <String>[], units),
        equals('--'),
      );
    });

    test('formats rating with one decimal place', () {
      expect(
        adapter.formatValue(DiveCenterField.rating, 4.7, units),
        equals('4.7'),
      );
    });

    test('formats integer rating with one decimal place', () {
      expect(
        adapter.formatValue(DiveCenterField.rating, 5.0, units),
        equals('5.0'),
      );
    });

    test('formats latitude with 5 decimal places', () {
      expect(
        adapter.formatValue(DiveCenterField.latitude, 35.89780, units),
        equals('35.89780'),
      );
    });

    test('formats longitude with 5 decimal places', () {
      expect(
        adapter.formatValue(DiveCenterField.longitude, 14.51220, units),
        equals('14.51220'),
      );
    });

    test('formats diveCount as string', () {
      expect(
        adapter.formatValue(DiveCenterField.diveCount, 42, units),
        equals('42'),
      );
    });

    test('formats zero diveCount as string', () {
      expect(
        adapter.formatValue(DiveCenterField.diveCount, 0, units),
        equals('0'),
      );
    });

    test('returns string values for text fields', () {
      expect(
        adapter.formatValue(DiveCenterField.centerName, 'Blue Water', units),
        equals('Blue Water'),
      );
    });

    test('returns string for city', () {
      expect(
        adapter.formatValue(DiveCenterField.city, 'Valletta', units),
        equals('Valletta'),
      );
    });

    test('returns string for country', () {
      expect(
        adapter.formatValue(DiveCenterField.country, 'Malta', units),
        equals('Malta'),
      );
    });

    test('returns string for phone', () {
      expect(
        adapter.formatValue(DiveCenterField.phone, '+356 1234 5678', units),
        equals('+356 1234 5678'),
      );
    });

    test('returns string for email', () {
      expect(
        adapter.formatValue(DiveCenterField.email, 'info@bluewater.mt', units),
        equals('info@bluewater.mt'),
      );
    });

    test('returns -- for empty string in text fields', () {
      expect(
        adapter.formatValue(DiveCenterField.notes, '', units),
        equals('--'),
      );
    });

    test('returns -- for empty city', () {
      expect(
        adapter.formatValue(DiveCenterField.city, '', units),
        equals('--'),
      );
    });

    test('returns -- for null rating', () {
      expect(
        adapter.formatValue(DiveCenterField.rating, null, units),
        equals('--'),
      );
    });

    test('returns -- for null latitude', () {
      expect(
        adapter.formatValue(DiveCenterField.latitude, null, units),
        equals('--'),
      );
    });

    test('returns -- for null longitude', () {
      expect(
        adapter.formatValue(DiveCenterField.longitude, null, units),
        equals('--'),
      );
    });
  });

  group('DiveCenterFieldAdapter.fieldFromName', () {
    final adapter = DiveCenterFieldAdapter.instance;

    test('resolves centerName', () {
      expect(
        adapter.fieldFromName('centerName'),
        equals(DiveCenterField.centerName),
      );
    });

    test('resolves city', () {
      expect(adapter.fieldFromName('city'), equals(DiveCenterField.city));
    });

    test('resolves country', () {
      expect(adapter.fieldFromName('country'), equals(DiveCenterField.country));
    });

    test('resolves stateProvince', () {
      expect(
        adapter.fieldFromName('stateProvince'),
        equals(DiveCenterField.stateProvince),
      );
    });

    test('resolves street', () {
      expect(adapter.fieldFromName('street'), equals(DiveCenterField.street));
    });

    test('resolves postalCode', () {
      expect(
        adapter.fieldFromName('postalCode'),
        equals(DiveCenterField.postalCode),
      );
    });

    test('resolves phone', () {
      expect(adapter.fieldFromName('phone'), equals(DiveCenterField.phone));
    });

    test('resolves email', () {
      expect(adapter.fieldFromName('email'), equals(DiveCenterField.email));
    });

    test('resolves website', () {
      expect(adapter.fieldFromName('website'), equals(DiveCenterField.website));
    });

    test('resolves affiliations', () {
      expect(
        adapter.fieldFromName('affiliations'),
        equals(DiveCenterField.affiliations),
      );
    });

    test('resolves rating', () {
      expect(adapter.fieldFromName('rating'), equals(DiveCenterField.rating));
    });

    test('resolves latitude', () {
      expect(
        adapter.fieldFromName('latitude'),
        equals(DiveCenterField.latitude),
      );
    });

    test('resolves longitude', () {
      expect(
        adapter.fieldFromName('longitude'),
        equals(DiveCenterField.longitude),
      );
    });

    test('resolves diveCount', () {
      expect(
        adapter.fieldFromName('diveCount'),
        equals(DiveCenterField.diveCount),
      );
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(DiveCenterField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('DiveCenterField EntityField properties', () {
    test('displayName is set for all fields', () {
      expect(DiveCenterField.centerName.displayName, equals('Name'));
      expect(DiveCenterField.city.displayName, equals('City'));
      expect(DiveCenterField.country.displayName, equals('Country'));
      expect(
        DiveCenterField.stateProvince.displayName,
        equals('State / Province'),
      );
      expect(DiveCenterField.street.displayName, equals('Street'));
      expect(DiveCenterField.postalCode.displayName, equals('Postal Code'));
      expect(DiveCenterField.phone.displayName, equals('Phone'));
      expect(DiveCenterField.email.displayName, equals('Email'));
      expect(DiveCenterField.website.displayName, equals('Website'));
      expect(DiveCenterField.affiliations.displayName, equals('Affiliations'));
      expect(DiveCenterField.rating.displayName, equals('Rating'));
      expect(DiveCenterField.latitude.displayName, equals('Latitude'));
      expect(DiveCenterField.longitude.displayName, equals('Longitude'));
      expect(DiveCenterField.diveCount.displayName, equals('Dive Count'));
      expect(DiveCenterField.notes.displayName, equals('Notes'));
    });

    test('shortLabel is set for all fields', () {
      expect(DiveCenterField.centerName.shortLabel, equals('Name'));
      expect(DiveCenterField.city.shortLabel, equals('City'));
      expect(DiveCenterField.country.shortLabel, equals('Country'));
      expect(DiveCenterField.stateProvince.shortLabel, equals('State'));
      expect(DiveCenterField.street.shortLabel, equals('Street'));
      expect(DiveCenterField.postalCode.shortLabel, equals('ZIP'));
      expect(DiveCenterField.phone.shortLabel, equals('Phone'));
      expect(DiveCenterField.email.shortLabel, equals('Email'));
      expect(DiveCenterField.website.shortLabel, equals('Website'));
      expect(DiveCenterField.affiliations.shortLabel, equals('Affiliations'));
      expect(DiveCenterField.rating.shortLabel, equals('Rating'));
      expect(DiveCenterField.latitude.shortLabel, equals('Lat'));
      expect(DiveCenterField.longitude.shortLabel, equals('Lon'));
      expect(DiveCenterField.diveCount.shortLabel, equals('Dives'));
      expect(DiveCenterField.notes.shortLabel, equals('Notes'));
    });

    test('icon is set for all fields', () {
      expect(DiveCenterField.centerName.icon, equals(Icons.store));
      expect(DiveCenterField.city.icon, equals(Icons.location_city));
      expect(DiveCenterField.country.icon, equals(Icons.flag));
      expect(DiveCenterField.stateProvince.icon, equals(Icons.map));
      expect(DiveCenterField.street.icon, equals(Icons.signpost));
      expect(DiveCenterField.postalCode.icon, equals(Icons.local_post_office));
      expect(DiveCenterField.phone.icon, equals(Icons.phone));
      expect(DiveCenterField.email.icon, equals(Icons.email));
      expect(DiveCenterField.website.icon, equals(Icons.language));
      expect(DiveCenterField.affiliations.icon, equals(Icons.badge));
      expect(DiveCenterField.rating.icon, equals(Icons.star));
      expect(DiveCenterField.latitude.icon, equals(Icons.explore));
      expect(DiveCenterField.longitude.icon, equals(Icons.explore));
      expect(DiveCenterField.diveCount.icon, equals(Icons.scuba_diving));
      expect(DiveCenterField.notes.icon, equals(Icons.notes));
    });

    test('defaultWidth is positive for all fields', () {
      for (final field in DiveCenterField.values) {
        expect(field.defaultWidth, greaterThan(0), reason: field.name);
      }
    });

    test('specific defaultWidth values', () {
      expect(DiveCenterField.centerName.defaultWidth, equals(150));
      expect(DiveCenterField.city.defaultWidth, equals(100));
      expect(DiveCenterField.country.defaultWidth, equals(100));
      expect(DiveCenterField.stateProvince.defaultWidth, equals(100));
      expect(DiveCenterField.street.defaultWidth, equals(130));
      expect(DiveCenterField.postalCode.defaultWidth, equals(90));
      expect(DiveCenterField.phone.defaultWidth, equals(110));
      expect(DiveCenterField.email.defaultWidth, equals(150));
      expect(DiveCenterField.website.defaultWidth, equals(150));
      expect(DiveCenterField.affiliations.defaultWidth, equals(120));
      expect(DiveCenterField.rating.defaultWidth, equals(70));
      expect(DiveCenterField.latitude.defaultWidth, equals(90));
      expect(DiveCenterField.longitude.defaultWidth, equals(90));
      expect(DiveCenterField.diveCount.defaultWidth, equals(80));
      expect(DiveCenterField.notes.defaultWidth, equals(150));
    });

    test('minWidth is positive and <= defaultWidth for all fields', () {
      for (final field in DiveCenterField.values) {
        expect(field.minWidth, greaterThan(0), reason: field.name);
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: field.name,
        );
      }
    });

    test('specific minWidth values', () {
      expect(DiveCenterField.centerName.minWidth, equals(80));
      expect(DiveCenterField.city.minWidth, equals(60));
      expect(DiveCenterField.country.minWidth, equals(60));
      expect(DiveCenterField.stateProvince.minWidth, equals(60));
      expect(DiveCenterField.street.minWidth, equals(80));
      expect(DiveCenterField.postalCode.minWidth, equals(60));
      expect(DiveCenterField.phone.minWidth, equals(70));
      expect(DiveCenterField.email.minWidth, equals(80));
      expect(DiveCenterField.website.minWidth, equals(80));
      expect(DiveCenterField.affiliations.minWidth, equals(60));
      expect(DiveCenterField.rating.minWidth, equals(50));
      expect(DiveCenterField.latitude.minWidth, equals(60));
      expect(DiveCenterField.longitude.minWidth, equals(60));
      expect(DiveCenterField.diveCount.minWidth, equals(50));
      expect(DiveCenterField.notes.minWidth, equals(60));
    });

    test('sortable is correct for all fields', () {
      expect(DiveCenterField.centerName.sortable, isTrue);
      expect(DiveCenterField.city.sortable, isTrue);
      expect(DiveCenterField.country.sortable, isTrue);
      expect(DiveCenterField.stateProvince.sortable, isTrue);
      expect(DiveCenterField.street.sortable, isTrue);
      expect(DiveCenterField.postalCode.sortable, isTrue);
      expect(DiveCenterField.phone.sortable, isFalse);
      expect(DiveCenterField.email.sortable, isFalse);
      expect(DiveCenterField.website.sortable, isFalse);
      expect(DiveCenterField.affiliations.sortable, isFalse);
      expect(DiveCenterField.rating.sortable, isTrue);
      expect(DiveCenterField.latitude.sortable, isTrue);
      expect(DiveCenterField.longitude.sortable, isTrue);
      expect(DiveCenterField.diveCount.sortable, isTrue);
      expect(DiveCenterField.notes.sortable, isFalse);
    });

    test('categoryName is set for all fields', () {
      expect(DiveCenterField.centerName.categoryName, equals('core'));
      expect(DiveCenterField.city.categoryName, equals('core'));
      expect(DiveCenterField.country.categoryName, equals('core'));
      expect(DiveCenterField.diveCount.categoryName, equals('core'));
      expect(DiveCenterField.street.categoryName, equals('address'));
      expect(DiveCenterField.stateProvince.categoryName, equals('address'));
      expect(DiveCenterField.postalCode.categoryName, equals('address'));
      expect(DiveCenterField.phone.categoryName, equals('contact'));
      expect(DiveCenterField.email.categoryName, equals('contact'));
      expect(DiveCenterField.website.categoryName, equals('contact'));
      expect(DiveCenterField.affiliations.categoryName, equals('details'));
      expect(DiveCenterField.rating.categoryName, equals('details'));
      expect(DiveCenterField.notes.categoryName, equals('details'));
      expect(DiveCenterField.latitude.categoryName, equals('coordinates'));
      expect(DiveCenterField.longitude.categoryName, equals('coordinates'));
    });

    test('isRightAligned is correct for all fields', () {
      expect(DiveCenterField.rating.isRightAligned, isTrue);
      expect(DiveCenterField.latitude.isRightAligned, isTrue);
      expect(DiveCenterField.longitude.isRightAligned, isTrue);
      expect(DiveCenterField.diveCount.isRightAligned, isTrue);
      for (final field in DiveCenterField.values) {
        if (field != DiveCenterField.rating &&
            field != DiveCenterField.latitude &&
            field != DiveCenterField.longitude &&
            field != DiveCenterField.diveCount) {
          expect(field.isRightAligned, isFalse, reason: field.name);
        }
      }
    });
  });
}
