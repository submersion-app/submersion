import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('TripType', () {
    test('has all expected values', () {
      expect(TripType.values, hasLength(4));
      expect(TripType.shore.name, 'shore');
      expect(TripType.liveaboard.name, 'liveaboard');
      expect(TripType.resort.name, 'resort');
      expect(TripType.dayTrip.name, 'dayTrip');
    });

    test('displayName returns human-readable names', () {
      expect(TripType.shore.displayName, 'Shore');
      expect(TripType.liveaboard.displayName, 'Liveaboard');
      expect(TripType.resort.displayName, 'Resort');
      expect(TripType.dayTrip.displayName, 'Day Trip');
    });

    test('fromName parses valid names', () {
      expect(TripType.fromName('shore'), TripType.shore);
      expect(TripType.fromName('liveaboard'), TripType.liveaboard);
      expect(TripType.fromName('resort'), TripType.resort);
      expect(TripType.fromName('dayTrip'), TripType.dayTrip);
    });

    test('fromName returns shore for unknown values', () {
      expect(TripType.fromName('unknown'), TripType.shore);
      expect(TripType.fromName(''), TripType.shore);
    });
  });

  group('DayType', () {
    test('has all expected values', () {
      expect(DayType.values, hasLength(7));
      expect(DayType.diveDay.name, 'diveDay');
      expect(DayType.seaDay.name, 'seaDay');
      expect(DayType.portDay.name, 'portDay');
      expect(DayType.embark.name, 'embark');
      expect(DayType.disembark.name, 'disembark');
      // Stored by name, so these strings are a sync contract (#2845).
      expect(DayType.travel.name, 'travel');
      expect(DayType.rest.name, 'rest');
    });

    test('displayName returns human-readable names', () {
      expect(DayType.diveDay.displayName, 'Dive Day');
      expect(DayType.seaDay.displayName, 'Sea Day');
      expect(DayType.portDay.displayName, 'Port Day');
      expect(DayType.embark.displayName, 'Embark');
      expect(DayType.disembark.displayName, 'Disembark');
      expect(DayType.travel.displayName, 'Travel');
      expect(DayType.rest.displayName, 'Rest');
    });

    test('fromName parses valid names', () {
      expect(DayType.fromName('diveDay'), DayType.diveDay);
      expect(DayType.fromName('seaDay'), DayType.seaDay);
      expect(DayType.fromName('embark'), DayType.embark);
      expect(DayType.fromName('travel'), DayType.travel);
      expect(DayType.fromName('rest'), DayType.rest);
    });

    test('fromName returns diveDay for unknown values', () {
      expect(DayType.fromName('unknown'), DayType.diveDay);
    });
  });
}
