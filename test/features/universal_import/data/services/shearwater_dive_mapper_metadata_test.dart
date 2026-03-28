import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

void main() {
  group('ShearwaterDiveMapper', () {
    group('mapDiveMetadata', () {
      test('maps core metadata fields', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test123',
          diveDate: '2025-12-27 14:01:08',
          depth: 26.80,
          averageDepth: 19.45,
          diveLengthTime: 1764,
          diveNumber: '23',
          serialNumber: '69FE56D7',
          location: 'Shark River, NJ, USA',
          site: 'Maclearie Park',
          buddy: 'John Doe',
          notes: 'Great dive',
          environment: 'Ocean/Sea',
          visibility: '30',
          weather: 'Sunny',
          conditions: 'Current',
          airTemperature: '72',
          weight: '14',
          dress: 'Wet Suit',
          fileName: 'Teric[69FE56D7]#23 2025-12-27 14-01-08.swlogzp',
          footerJson: {'UnitSystem': 1, 'DiveTimeInSeconds': 1764},
          tankProfileData: {
            'GasProfiles': [
              {'O2Percent': 32, 'HePercent': 0, 'CircuitMode': 1},
            ],
            'TankData': [
              {
                'StartPressurePSI': '2960',
                'EndPressurePSI': '1088',
                'GasProfile': {'O2Percent': 32, 'HePercent': 0},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1015.0,
              },
            ],
          },
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['importSource'], 'shearwater_cloud');
        expect(result['importId'], 'test123');
        expect(result['dateTime'], isA<DateTime>());
        expect((result['dateTime'] as DateTime).year, 2025);
        expect((result['dateTime'] as DateTime).month, 12);
        expect((result['dateTime'] as DateTime).day, 27);
        expect((result['dateTime'] as DateTime).isUtc, isTrue);
        // 26.80 ft = 8.169 m, 19.45 ft = 5.928 m (imperial -> metric)
        expect(result['maxDepth'], closeTo(8.169, 0.001));
        expect(result['avgDepth'], closeTo(5.928, 0.001));
        expect(result['runtime'], const Duration(seconds: 1764));
        expect(result['diveNumber'], 23);
        expect(result['buddyRefs'], ['John Doe']);
        expect(result['siteName'], 'Maclearie Park');
        expect(result['diveComputerModel'], 'Teric');
        expect(result['diveComputerSerial'], '69FE56D7');
        expect(result['notes'], contains('Great dive'));
      });

      test('maps conditions to structured enums', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          environment: 'Ocean/Sea',
          visibility: '30',
          weather: 'Sunny',
          conditions: 'Current',
          footerJson: {'UnitSystem': 1},
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['waterType'], WaterType.salt);
        expect(result['visibility'], Visibility.moderate);
        expect(result['cloudCover'], CloudCover.clear);
        expect(result['currentStrength'], CurrentStrength.moderate);
      });

      test('converts imperial units', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          depth: 90.0,
          averageDepth: 60.0,
          airTemperature: '72',
          weight: '14',
          footerJson: {'UnitSystem': 1},
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        // 90 ft = 27.432 m
        expect(result['maxDepth'], closeTo(27.432, 0.001));
        // 60 ft = 18.288 m
        expect(result['avgDepth'], closeTo(18.288, 0.001));
        // 72F = 22.2C
        expect(result['airTemp'], closeTo(22.2, 0.1));
        // 14lbs = 6.35kg
        expect(result['weightAmount'], closeTo(6.35, 0.01));
      });

      test('does not convert metric units', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          depth: 27.0,
          averageDepth: 18.0,
          airTemperature: '22',
          weight: '6',
          footerJson: {'UnitSystem': 0},
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['maxDepth'], 27.0);
        expect(result['avgDepth'], 18.0);
        expect(result['airTemp'], closeTo(22.0, 0.1));
        expect(result['weightAmount'], closeTo(6.0, 0.01));
      });

      test('includes notes with extra notes appended', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          notes: 'Great dive',
          dress: 'Wet Suit',
          footerJson: {'UnitSystem': 0},
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
        final notes = result['notes'] as String;

        expect(notes, contains('Great dive'));
        expect(notes, contains('Dress: Wet Suit'));
      });

      test('handles notes when only user notes present', () {
        const rawDive = ShearwaterRawDive(diveId: 'test', notes: 'Great dive');

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['notes'], 'Great dive');
      });

      test('handles notes when only extra notes present', () {
        const rawDive = ShearwaterRawDive(diveId: 'test', dress: 'Dry Suit');

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
        final notes = result['notes'] as String;

        expect(notes, contains('Dress: Dry Suit'));
      });

      test('maps site reference for matching', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          site: 'Maclearie Park',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['siteName'], 'Maclearie Park');
        expect(result['site'], isA<Map<String, dynamic>>());
        expect((result['site'] as Map)['name'], 'Maclearie Park');
        expect((result['site'] as Map)['uddfId'], 'Maclearie Park');
      });

      test('extracts surface pressure from tank data', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '3000',
                'EndPressurePSI': '1000',
                'GasProfile': {'O2Percent': 21, 'HePercent': 0},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1013.0,
              },
            ],
          },
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        // 1013 mbar = 1.013 bar
        expect(result['surfacePressure'], closeTo(1.013, 0.001));
      });

      test('handles dive with no metadata gracefully', () {
        const rawDive = ShearwaterRawDive(diveId: 'empty');

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['importSource'], 'shearwater_cloud');
        expect(result['importId'], 'empty');
        expect(result['dateTime'], isNull);
        expect(result['maxDepth'], isNull);
        expect(result['tanks'], isEmpty);
      });

      test('maps dive computer info from filename', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          fileName: 'Perdix 2[AABB1234]#5 2025-01-15 09-30-00.swlogzp',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['diveComputerModel'], 'Perdix 2');
        expect(result['diveComputerSerial'], 'AABB1234');
      });

      test('defaults to oc diveMode when no apparatus set', () {
        const rawDive = ShearwaterRawDive(diveId: 'test');

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['diveMode'], DiveMode.oc);
      });

      test('maps CCR apparatus to ccr diveMode', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          apparatus: 'Closed Circuit',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['diveMode'], DiveMode.ccr);
      });

      test('maps SCR apparatus to scr diveMode', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          apparatus: 'Semi-Closed',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

        expect(result['diveMode'], DiveMode.scr);
      });

      test('normalizes naive datetime to UTC wall-time', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          diveDate: '2025-06-15 10:30:00',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
        final dt = result['dateTime'] as DateTime;

        expect(dt.isUtc, isTrue);
        expect(dt.hour, 10);
        expect(dt.minute, 30);
      });

      test('preserves UTC datetime as-is', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          diveDate: '2025-06-15T10:30:00Z',
        );

        final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
        final dt = result['dateTime'] as DateTime;

        expect(dt.isUtc, isTrue);
        expect(dt.hour, 10);
        expect(dt.minute, 30);
      });
    });

    group('mapTanks', () {
      test('maps active tanks with gas mix and pressures', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test123',
          footerJson: {'UnitSystem': 1},
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '2960',
                'EndPressurePSI': '1088',
                'GasProfile': {'O2Percent': 32, 'HePercent': 0},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1015.0,
              },
              {
                'StartPressurePSI': '',
                'EndPressurePSI': '',
                'GasProfile': {'O2Percent': 21, 'HePercent': 0},
                'DiveTransmitter': {
                  'TankIndex': 1,
                  'IsOn': false,
                  'Name': 'T2',
                },
                'SurfacePressureMBar': 1015.0,
              },
            ],
          },
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, hasLength(1));
        expect((tanks[0]['gasMix'] as GasMix).o2, 32);
        expect((tanks[0]['gasMix'] as GasMix).he, 0);
        expect(tanks[0]['startPressure'], closeTo(204.1, 0.5));
        expect(tanks[0]['endPressure'], closeTo(75.0, 0.5));
        expect(tanks[0]['name'], 'T1');
      });

      test('maps multiple active tanks', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          footerJson: {'UnitSystem': 1},
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '3000',
                'EndPressurePSI': '1500',
                'GasProfile': {'O2Percent': 32, 'HePercent': 0},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1013.0,
              },
              {
                'StartPressurePSI': '3000',
                'EndPressurePSI': '2800',
                'GasProfile': {'O2Percent': 100, 'HePercent': 0},
                'DiveTransmitter': {
                  'TankIndex': 1,
                  'IsOn': true,
                  'Name': 'Deco',
                },
                'SurfacePressureMBar': 1013.0,
              },
            ],
          },
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, hasLength(2));
        expect((tanks[0]['gasMix'] as GasMix).o2, 32);
        expect(tanks[0]['name'], 'T1');
        expect((tanks[1]['gasMix'] as GasMix).o2, 100);
        expect(tanks[1]['name'], 'Deco');
      });

      test('maps trimix tank', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          footerJson: {'UnitSystem': 1},
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '3000',
                'EndPressurePSI': '1000',
                'GasProfile': {'O2Percent': 21, 'HePercent': 35},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1013.0,
              },
            ],
          },
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, hasLength(1));
        expect((tanks[0]['gasMix'] as GasMix).o2, 21);
        expect((tanks[0]['gasMix'] as GasMix).he, 35);
      });

      test('returns empty list when no tank data', () {
        const rawDive = ShearwaterRawDive(diveId: 'test');

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, isEmpty);
      });

      test('returns empty list when TankData is missing', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          tankProfileData: {'GasProfiles': []},
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, isEmpty);
      });

      test('handles tanks with missing pressure values', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          footerJson: {'UnitSystem': 1},
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '',
                'EndPressurePSI': '',
                'GasProfile': {'O2Percent': 32, 'HePercent': 0},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
                'SurfacePressureMBar': 1013.0,
              },
            ],
          },
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

        expect(tanks, hasLength(1));
        expect(tanks[0]['startPressure'], isNull);
        expect(tanks[0]['endPressure'], isNull);
      });
    });

    group('mapSites', () {
      test('maps site from location and site fields', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test123',
          location: 'Shark River, NJ, USA',
          site: 'Maclearie Park',
        );

        final sites = ShearwaterDiveMapper.mapSites([rawDive]);

        expect(sites, hasLength(1));
        expect(sites[0]['name'], 'Maclearie Park');
        expect(sites[0]['uddfId'], 'Maclearie Park');
      });

      test('deduplicates sites by name', () {
        final dives = [
          const ShearwaterRawDive(
            diveId: '1',
            site: 'Same Site',
            location: 'NJ',
          ),
          const ShearwaterRawDive(
            diveId: '2',
            site: 'Same Site',
            location: 'NJ',
          ),
          const ShearwaterRawDive(
            diveId: '3',
            site: 'Other Site',
            location: 'FL',
          ),
        ];

        final sites = ShearwaterDiveMapper.mapSites(dives);

        expect(sites, hasLength(2));
        final names = sites.map((s) => s['name']).toSet();
        expect(names, containsAll(['Same Site', 'Other Site']));
      });

      test('skips dives with no site name', () {
        final dives = [
          const ShearwaterRawDive(diveId: '1', site: 'Named Site'),
          const ShearwaterRawDive(diveId: '2'),
          const ShearwaterRawDive(diveId: '3', site: null),
        ];

        final sites = ShearwaterDiveMapper.mapSites(dives);

        expect(sites, hasLength(1));
        expect(sites[0]['name'], 'Named Site');
      });

      test('returns empty list when no dives have sites', () {
        final dives = [
          const ShearwaterRawDive(diveId: '1'),
          const ShearwaterRawDive(diveId: '2'),
        ];

        final sites = ShearwaterDiveMapper.mapSites(dives);

        expect(sites, isEmpty);
      });

      test('includes location as notes', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          site: 'My Site',
          location: 'Some Location',
        );

        final sites = ShearwaterDiveMapper.mapSites([rawDive]);

        expect(sites[0]['notes'], 'Some Location');
      });

      test('parses GNSS entry location to lat/lon', () {
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          site: 'GPS Site',
          gnssEntryLocation: '40.1234,-74.5678',
        );

        final sites = ShearwaterDiveMapper.mapSites([rawDive]);

        expect(sites[0]['latitude'], closeTo(40.1234, 0.0001));
        expect(sites[0]['longitude'], closeTo(-74.5678, 0.0001));
      });
    });

    group('_toDouble fallback', () {
      test('string-to-double fallback via mapTanks', () {
        // _toDouble is private but exercised through mapTanks when
        // GasProfile values are strings instead of nums.
        const rawDive = ShearwaterRawDive(
          diveId: 'test',
          tankProfileData: {
            'TankData': [
              {
                'StartPressurePSI': '3000',
                'EndPressurePSI': '1000',
                'GasProfile': {'O2Percent': '32.0', 'HePercent': '10.0'},
                'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
              },
            ],
          },
        );

        final tanks = ShearwaterDiveMapper.mapTanks(rawDive);
        expect(tanks, hasLength(1));
        expect((tanks[0]['gasMix'] as GasMix).o2, 32.0);
        expect((tanks[0]['gasMix'] as GasMix).he, 10.0);
      });
    });
  });
}
