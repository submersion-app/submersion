import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divemate_dive_fields.dart';
import 'package:submersion/features/universal_import/data/services/divemate_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

const _book = DivingLogLogbook(
  dives: [],
  capabilities: DivingLogCapabilities(tables: {}, columns: {}),
  placesById: {7: DivingLogRawPlace(id: 7, water: 1)},
);

void main() {
  group('applyToDive', () {
    test('a Diving Log dive is left alone', () {
      final dive = <String, dynamic>{'notes': 'n'};
      DiveMateDiveFields.applyToDive(
        dive,
        const DivingLogRawDive(id: 1),
        _book,
      );
      expect(dive, {'notes': 'n'});
    });

    test('the site water stands in when the dive has none', () {
      final dive = <String, dynamic>{};
      DiveMateDiveFields.applyToDive(
        dive,
        const DivingLogRawDive(
          id: 1,
          placeId: 7,
          diveMate: DiveMateDiveExtras(water: 0),
        ),
        _book,
      );
      expect(dive['waterType'], 'salt');
    });

    test('text no field holds is appended to the notes', () {
      final dive = <String, dynamic>{'notes': 'great dive'};
      DiveMateDiveFields.applyToDive(
        dive,
        const DivingLogRawDive(
          id: 1,
          diveMate: DiveMateDiveExtras(
            visibility: 'trüb nach Sturm',
            current: 'Gegenströmung am Riff',
          ),
        ),
        _book,
      );
      expect(
        dive['notes'],
        'great dive\n\nVisibility: trüb nach Sturm\n'
        'Current: Gegenströmung am Riff',
      );
      expect(dive.containsKey('visibility'), isFalse);
      expect(dive.containsKey('currentStrength'), isFalse);
    });

    test('leftover text becomes the notes when there were none', () {
      final dive = <String, dynamic>{};
      DiveMateDiveFields.applyToDive(
        dive,
        const DivingLogRawDive(
          id: 1,
          diveMate: DiveMateDiveExtras(current: 'Gegenströmung'),
        ),
        _book,
      );
      expect(dive['notes'], 'Current: Gegenströmung');
    });
  });

  group('applyToTanks', () {
    test('a tank without DiveMate extras is left alone', () {
      final tanks = [
        <String, dynamic>{'order': 0},
      ];
      DiveMateDiveFields.applyToTanks(tanks, const [
        DivingLogRawTank(tankId: 1),
      ]);
      expect(tanks.single, {'order': 0});
    });
  });
}
