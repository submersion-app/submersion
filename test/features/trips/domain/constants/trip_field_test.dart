import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative TripWithStats entity for adapter tests.
  final testTrip = Trip(
    id: 'trip-1',
    diverId: 'diver-1',
    name: 'Malta Dive Trip',
    startDate: DateTime(2024, 6, 1),
    endDate: DateTime(2024, 6, 8),
    location: 'Gozo, Malta',
    tripType: TripType.resort,
    resortName: 'Blue Lagoon Resort',
    liveaboardName: null,
    notes: 'Amazing trip',
    createdAt: DateTime(2024, 6, 1),
    updatedAt: DateTime(2024, 6, 8),
  );

  final testEntity = TripWithStats(
    trip: testTrip,
    diveCount: 14,
    totalBottomTime: 12600, // 210 minutes = 3h 30m in seconds
    maxDepth: 35.0,
    avgDepth: 18.5,
  );

  group('TripFieldAdapter.allFields', () {
    test('has expected count matching TripField.values', () {
      expect(
        TripFieldAdapter.instance.allFields.length,
        equals(TripField.values.length),
      );
    });

    test('contains all TripField values', () {
      expect(
        TripFieldAdapter.instance.allFields,
        containsAll(TripField.values),
      );
    });
  });

  group('TripFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = TripFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          TripField.tripName,
          TripField.startDate,
          TripField.endDate,
          TripField.durationDays,
          TripField.location,
          TripField.tripType,
        ]),
      );
    });

    test('groups accommodation fields together', () {
      final byCategory = TripFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['accommodation'],
        containsAll([TripField.resortName, TripField.liveaboardName]),
      );
    });

    test('groups statistics fields together', () {
      final byCategory = TripFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['statistics'],
        containsAll([
          TripField.diveCount,
          TripField.totalBottomTime,
          TripField.maxDepth,
          TripField.avgDepth,
        ]),
      );
    });

    test('groups other fields together', () {
      final byCategory = TripFieldAdapter.instance.fieldsByCategory;
      expect(byCategory['other'], containsAll([TripField.notes]));
    });

    test('covers all TripField values across categories', () {
      final byCategory = TripFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(TripField.values.length));
    });
  });

  group('TripFieldAdapter.extractValue', () {
    final adapter = TripFieldAdapter.instance;

    test('returns trip name', () {
      expect(
        adapter.extractValue(TripField.tripName, testEntity),
        equals('Malta Dive Trip'),
      );
    });

    test('returns startDate', () {
      expect(
        adapter.extractValue(TripField.startDate, testEntity),
        equals(DateTime(2024, 6, 1)),
      );
    });

    test('returns endDate', () {
      expect(
        adapter.extractValue(TripField.endDate, testEntity),
        equals(DateTime(2024, 6, 8)),
      );
    });

    test('returns durationDays (computed)', () {
      // June 1 to June 8 = 7 days difference + 1 = 8
      expect(
        adapter.extractValue(TripField.durationDays, testEntity),
        equals(8),
      );
    });

    test('returns location', () {
      expect(
        adapter.extractValue(TripField.location, testEntity),
        equals('Gozo, Malta'),
      );
    });

    test('returns tripType enum', () {
      expect(
        adapter.extractValue(TripField.tripType, testEntity),
        equals(TripType.resort),
      );
    });

    test('returns resortName', () {
      expect(
        adapter.extractValue(TripField.resortName, testEntity),
        equals('Blue Lagoon Resort'),
      );
    });

    test('returns liveaboardName (null)', () {
      expect(
        adapter.extractValue(TripField.liveaboardName, testEntity),
        isNull,
      );
    });

    test('returns diveCount', () {
      expect(adapter.extractValue(TripField.diveCount, testEntity), equals(14));
    });

    test('returns totalBottomTime in seconds', () {
      expect(
        adapter.extractValue(TripField.totalBottomTime, testEntity),
        equals(12600),
      );
    });

    test('returns maxDepth', () {
      expect(
        adapter.extractValue(TripField.maxDepth, testEntity),
        equals(35.0),
      );
    });

    test('returns avgDepth', () {
      expect(
        adapter.extractValue(TripField.avgDepth, testEntity),
        equals(18.5),
      );
    });

    test('returns notes', () {
      expect(
        adapter.extractValue(TripField.notes, testEntity),
        equals('Amazing trip'),
      );
    });

    test('returns null for location when null', () {
      final noLocation = TripWithStats(trip: testTrip.copyWith(location: null));
      expect(adapter.extractValue(TripField.location, noLocation), isNull);
    });

    test('returns null for maxDepth when null', () {
      final noDepth = TripWithStats(trip: testTrip);
      expect(adapter.extractValue(TripField.maxDepth, noDepth), isNull);
    });

    test('returns null for avgDepth when null', () {
      final noDepth = TripWithStats(trip: testTrip);
      expect(adapter.extractValue(TripField.avgDepth, noDepth), isNull);
    });
  });

  group('TripFieldAdapter.formatValue', () {
    final adapter = TripFieldAdapter.instance;
    final dateFormat = DateFormat.yMMMd();

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(TripField.tripName, null, units),
        equals('--'),
      );
    });

    test('formats tripName as string', () {
      expect(
        adapter.formatValue(TripField.tripName, 'Malta Dive Trip', units),
        equals('Malta Dive Trip'),
      );
    });

    test('formats startDate with DateFormat.yMMMd()', () {
      final date = DateTime(2024, 6, 1);
      expect(
        adapter.formatValue(TripField.startDate, date, units),
        equals(dateFormat.format(date)),
      );
    });

    test('formats endDate with DateFormat.yMMMd()', () {
      final date = DateTime(2024, 6, 8);
      expect(
        adapter.formatValue(TripField.endDate, date, units),
        equals(dateFormat.format(date)),
      );
    });

    test('formats durationDays with days suffix', () {
      expect(
        adapter.formatValue(TripField.durationDays, 8, units),
        equals('8 days'),
      );
    });

    test('formats durationDays single day', () {
      expect(
        adapter.formatValue(TripField.durationDays, 1, units),
        equals('1 days'),
      );
    });

    test('formats location as string', () {
      expect(
        adapter.formatValue(TripField.location, 'Gozo, Malta', units),
        equals('Gozo, Malta'),
      );
    });

    test('formats empty location as --', () {
      expect(adapter.formatValue(TripField.location, '', units), equals('--'));
    });

    test('formats tripType using enum name', () {
      expect(
        adapter.formatValue(TripField.tripType, TripType.resort, units),
        equals('resort'),
      );
    });

    test('formats tripType liveaboard using enum name', () {
      expect(
        adapter.formatValue(TripField.tripType, TripType.liveaboard, units),
        equals('liveaboard'),
      );
    });

    test('formats tripType dayTrip using enum name', () {
      expect(
        adapter.formatValue(TripField.tripType, TripType.dayTrip, units),
        equals('dayTrip'),
      );
    });

    test('formats resortName as string', () {
      expect(
        adapter.formatValue(TripField.resortName, 'Blue Lagoon Resort', units),
        equals('Blue Lagoon Resort'),
      );
    });

    test('formats empty resortName as --', () {
      expect(
        adapter.formatValue(TripField.resortName, '', units),
        equals('--'),
      );
    });

    test('formats liveaboardName as string', () {
      expect(
        adapter.formatValue(TripField.liveaboardName, 'MV Explorer', units),
        equals('MV Explorer'),
      );
    });

    test('formats diveCount as integer string', () {
      expect(adapter.formatValue(TripField.diveCount, 14, units), equals('14'));
    });

    test('formats diveCount zero', () {
      expect(adapter.formatValue(TripField.diveCount, 0, units), equals('0'));
    });

    test('formats totalBottomTime with hours and minutes', () {
      // 12600 seconds = 3h 30m
      expect(
        adapter.formatValue(TripField.totalBottomTime, 12600, units),
        equals('3h 30m'),
      );
    });

    test('formats totalBottomTime with minutes only when under an hour', () {
      // 2700 seconds = 45m
      expect(
        adapter.formatValue(TripField.totalBottomTime, 2700, units),
        equals('45m'),
      );
    });

    test('formats totalBottomTime zero as --', () {
      expect(
        adapter.formatValue(TripField.totalBottomTime, 0, units),
        equals('--'),
      );
    });

    test('formats totalBottomTime negative as --', () {
      expect(
        adapter.formatValue(TripField.totalBottomTime, -1, units),
        equals('--'),
      );
    });

    test('formats totalBottomTime exact hour', () {
      // 3600 seconds = 1h 0m
      expect(
        adapter.formatValue(TripField.totalBottomTime, 3600, units),
        equals('1h 0m'),
      );
    });

    test('formats maxDepth using units.formatDepth', () {
      expect(
        adapter.formatValue(TripField.maxDepth, 35.0, units),
        equals(units.formatDepth(35.0)),
      );
    });

    test('formats avgDepth using units.formatDepth', () {
      expect(
        adapter.formatValue(TripField.avgDepth, 18.5, units),
        equals(units.formatDepth(18.5)),
      );
    });

    test('formats notes as string', () {
      expect(
        adapter.formatValue(TripField.notes, 'Amazing trip', units),
        equals('Amazing trip'),
      );
    });

    test('formats empty notes as --', () {
      expect(adapter.formatValue(TripField.notes, '', units), equals('--'));
    });

    test('returns -- for null maxDepth', () {
      expect(
        adapter.formatValue(TripField.maxDepth, null, units),
        equals('--'),
      );
    });

    test('returns -- for null avgDepth', () {
      expect(
        adapter.formatValue(TripField.avgDepth, null, units),
        equals('--'),
      );
    });

    test('returns -- for null liveaboardName', () {
      expect(
        adapter.formatValue(TripField.liveaboardName, null, units),
        equals('--'),
      );
    });
  });

  group('TripFieldAdapter.fieldFromName', () {
    final adapter = TripFieldAdapter.instance;

    test('resolves tripName', () {
      expect(adapter.fieldFromName('tripName'), equals(TripField.tripName));
    });

    test('resolves startDate', () {
      expect(adapter.fieldFromName('startDate'), equals(TripField.startDate));
    });

    test('resolves endDate', () {
      expect(adapter.fieldFromName('endDate'), equals(TripField.endDate));
    });

    test('resolves durationDays', () {
      expect(
        adapter.fieldFromName('durationDays'),
        equals(TripField.durationDays),
      );
    });

    test('resolves location', () {
      expect(adapter.fieldFromName('location'), equals(TripField.location));
    });

    test('resolves tripType', () {
      expect(adapter.fieldFromName('tripType'), equals(TripField.tripType));
    });

    test('resolves resortName', () {
      expect(adapter.fieldFromName('resortName'), equals(TripField.resortName));
    });

    test('resolves liveaboardName', () {
      expect(
        adapter.fieldFromName('liveaboardName'),
        equals(TripField.liveaboardName),
      );
    });

    test('resolves diveCount', () {
      expect(adapter.fieldFromName('diveCount'), equals(TripField.diveCount));
    });

    test('resolves totalBottomTime', () {
      expect(
        adapter.fieldFromName('totalBottomTime'),
        equals(TripField.totalBottomTime),
      );
    });

    test('resolves maxDepth', () {
      expect(adapter.fieldFromName('maxDepth'), equals(TripField.maxDepth));
    });

    test('resolves avgDepth', () {
      expect(adapter.fieldFromName('avgDepth'), equals(TripField.avgDepth));
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(TripField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('TripField EntityField properties', () {
    test('displayName is non-empty for all fields', () {
      for (final field in TripField.values) {
        expect(field.displayName, isNotEmpty, reason: field.name);
      }
    });

    test('shortLabel is non-empty for all fields', () {
      for (final field in TripField.values) {
        expect(field.shortLabel, isNotEmpty, reason: field.name);
      }
    });

    test('icon is non-null for all fields', () {
      for (final field in TripField.values) {
        expect(field.icon, isNotNull, reason: field.name);
      }
    });

    test('defaultWidth is positive for all fields', () {
      for (final field in TripField.values) {
        expect(field.defaultWidth, greaterThan(0), reason: field.name);
      }
    });

    test('minWidth is positive and <= defaultWidth for all fields', () {
      for (final field in TripField.values) {
        expect(field.minWidth, greaterThan(0), reason: field.name);
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: field.name,
        );
      }
    });

    test('categoryName is non-empty for all fields', () {
      for (final field in TripField.values) {
        expect(field.categoryName, isNotEmpty, reason: field.name);
      }
    });

    test('notes is not sortable', () {
      expect(TripField.notes.sortable, isFalse);
    });

    test('all fields except notes are sortable', () {
      for (final field in TripField.values) {
        if (field == TripField.notes) continue;
        expect(field.sortable, isTrue, reason: field.name);
      }
    });

    test('numeric fields are right-aligned', () {
      expect(TripField.durationDays.isRightAligned, isTrue);
      expect(TripField.diveCount.isRightAligned, isTrue);
      expect(TripField.totalBottomTime.isRightAligned, isTrue);
      expect(TripField.maxDepth.isRightAligned, isTrue);
      expect(TripField.avgDepth.isRightAligned, isTrue);
    });

    test('text fields are not right-aligned', () {
      expect(TripField.tripName.isRightAligned, isFalse);
      expect(TripField.location.isRightAligned, isFalse);
      expect(TripField.resortName.isRightAligned, isFalse);
      expect(TripField.liveaboardName.isRightAligned, isFalse);
      expect(TripField.notes.isRightAligned, isFalse);
      expect(TripField.startDate.isRightAligned, isFalse);
      expect(TripField.endDate.isRightAligned, isFalse);
      expect(TripField.tripType.isRightAligned, isFalse);
    });

    test('specific displayName values', () {
      expect(TripField.tripName.displayName, equals('Name'));
      expect(TripField.startDate.displayName, equals('Start Date'));
      expect(TripField.endDate.displayName, equals('End Date'));
      expect(TripField.durationDays.displayName, equals('Duration'));
      expect(TripField.location.displayName, equals('Location'));
      expect(TripField.tripType.displayName, equals('Trip Type'));
      expect(TripField.resortName.displayName, equals('Resort'));
      expect(TripField.liveaboardName.displayName, equals('Liveaboard'));
      expect(TripField.diveCount.displayName, equals('Dive Count'));
      expect(
        TripField.totalBottomTime.displayName,
        equals('Total Bottom Time'),
      );
      expect(TripField.maxDepth.displayName, equals('Max Depth'));
      expect(TripField.avgDepth.displayName, equals('Avg Depth'));
      expect(TripField.notes.displayName, equals('Notes'));
    });

    test('specific shortLabel values', () {
      expect(TripField.tripName.shortLabel, equals('Name'));
      expect(TripField.startDate.shortLabel, equals('Start'));
      expect(TripField.endDate.shortLabel, equals('End'));
      expect(TripField.durationDays.shortLabel, equals('Days'));
      expect(TripField.location.shortLabel, equals('Location'));
      expect(TripField.tripType.shortLabel, equals('Type'));
      expect(TripField.resortName.shortLabel, equals('Resort'));
      expect(TripField.liveaboardName.shortLabel, equals('Liveaboard'));
      expect(TripField.diveCount.shortLabel, equals('Dives'));
      expect(TripField.totalBottomTime.shortLabel, equals('BT Total'));
      expect(TripField.maxDepth.shortLabel, equals('Max D'));
      expect(TripField.avgDepth.shortLabel, equals('Avg D'));
      expect(TripField.notes.shortLabel, equals('Notes'));
    });

    test('specific icon values', () {
      expect(TripField.tripName.icon, equals(Icons.flight));
      expect(TripField.startDate.icon, equals(Icons.calendar_today));
      expect(TripField.endDate.icon, equals(Icons.event));
      expect(TripField.durationDays.icon, equals(Icons.timer));
      expect(TripField.location.icon, equals(Icons.place));
      expect(TripField.tripType.icon, equals(Icons.category));
      expect(TripField.resortName.icon, equals(Icons.hotel));
      expect(TripField.liveaboardName.icon, equals(Icons.directions_boat));
      expect(TripField.diveCount.icon, equals(Icons.scuba_diving));
      expect(TripField.totalBottomTime.icon, equals(Icons.access_time));
      expect(TripField.maxDepth.icon, equals(Icons.arrow_downward));
      expect(TripField.avgDepth.icon, equals(Icons.trending_down));
      expect(TripField.notes.icon, equals(Icons.notes));
    });

    test('specific defaultWidth values', () {
      expect(TripField.tripName.defaultWidth, equals(150));
      expect(TripField.startDate.defaultWidth, equals(110));
      expect(TripField.endDate.defaultWidth, equals(110));
      expect(TripField.durationDays.defaultWidth, equals(80));
      expect(TripField.location.defaultWidth, equals(120));
      expect(TripField.tripType.defaultWidth, equals(90));
      expect(TripField.resortName.defaultWidth, equals(120));
      expect(TripField.liveaboardName.defaultWidth, equals(120));
      expect(TripField.diveCount.defaultWidth, equals(80));
      expect(TripField.totalBottomTime.defaultWidth, equals(90));
      expect(TripField.maxDepth.defaultWidth, equals(80));
      expect(TripField.avgDepth.defaultWidth, equals(80));
      expect(TripField.notes.defaultWidth, equals(150));
    });

    test('specific minWidth values', () {
      expect(TripField.tripName.minWidth, equals(80));
      expect(TripField.startDate.minWidth, equals(70));
      expect(TripField.endDate.minWidth, equals(70));
      expect(TripField.durationDays.minWidth, equals(50));
      expect(TripField.location.minWidth, equals(70));
      expect(TripField.tripType.minWidth, equals(60));
      expect(TripField.resortName.minWidth, equals(70));
      expect(TripField.liveaboardName.minWidth, equals(70));
      expect(TripField.diveCount.minWidth, equals(50));
      expect(TripField.totalBottomTime.minWidth, equals(60));
      expect(TripField.maxDepth.minWidth, equals(50));
      expect(TripField.avgDepth.minWidth, equals(50));
      expect(TripField.notes.minWidth, equals(60));
    });

    test('specific categoryName values', () {
      expect(TripField.tripName.categoryName, equals('core'));
      expect(TripField.startDate.categoryName, equals('core'));
      expect(TripField.endDate.categoryName, equals('core'));
      expect(TripField.durationDays.categoryName, equals('core'));
      expect(TripField.location.categoryName, equals('core'));
      expect(TripField.tripType.categoryName, equals('core'));
      expect(TripField.resortName.categoryName, equals('accommodation'));
      expect(TripField.liveaboardName.categoryName, equals('accommodation'));
      expect(TripField.diveCount.categoryName, equals('statistics'));
      expect(TripField.totalBottomTime.categoryName, equals('statistics'));
      expect(TripField.maxDepth.categoryName, equals('statistics'));
      expect(TripField.avgDepth.categoryName, equals('statistics'));
      expect(TripField.notes.categoryName, equals('other'));
    });
  });
}
