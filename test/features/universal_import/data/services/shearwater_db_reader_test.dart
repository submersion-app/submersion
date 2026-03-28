import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

import 'shearwater_test_helpers.dart';

void main() {
  group('ShearwaterDbReader', () {
    group('isShearwaterCloudDb', () {
      test('returns true for valid Shearwater Cloud database', () async {
        final bytes = createShearwaterTestDb();
        final result = await ShearwaterDbReader.isShearwaterCloudDb(bytes);
        expect(result, isTrue);
      });

      test('returns false for non-SQLite bytes', () async {
        final result = await ShearwaterDbReader.isShearwaterCloudDb(
          Uint8List.fromList([1, 2, 3, 4]),
        );
        expect(result, isFalse);
      });

      test('returns false for empty bytes', () async {
        final result = await ShearwaterDbReader.isShearwaterCloudDb(
          Uint8List(0),
        );
        expect(result, isFalse);
      });

      test('returns false for SQLite DB missing dive_details', () async {
        final bytes = createShearwaterTestDb(includeDiveDetails: false);
        final result = await ShearwaterDbReader.isShearwaterCloudDb(bytes);
        expect(result, isFalse);
      });

      test('returns false for SQLite DB missing log_data', () async {
        final bytes = createShearwaterTestDb(includeLogData: false);
        final result = await ShearwaterDbReader.isShearwaterCloudDb(bytes);
        expect(result, isFalse);
      });
    });

    group('readDives', () {
      test('returns empty list for empty database', () async {
        final bytes = createShearwaterTestDb();
        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives, isEmpty);
      });

      test('reads dive metadata from dive_details', () async {
        final tankJson = jsonEncode({
          'GasProfiles': [
            {'O2Percent': 32, 'HePercent': 0},
          ],
          'TankData': [
            {
              'StartPressurePSI': '3000',
              'EndPressurePSI': '1500',
              'GasProfile': {'O2Percent': 32, 'HePercent': 0},
              'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
              'SurfacePressureMBar': 1013.0,
            },
          ],
        });

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(
              diveId: 'test-001',
              diveDate: '2025-06-15 10:30:00',
              depth: 26.8,
              averageDepth: 19.4,
              diveLengthTime: 1764,
              diveNumber: '23',
              serialNumber: '69FE56D7',
              location: 'Shark River, NJ',
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
              apparatus: 'Open Circuit',
              thermalComfort: 'Comfortable',
              workload: 'Light',
              gnssEntryLocation: '40.1234,-74.5678',
              tankProfileDataJson: tankJson,
              gasNotes: 'EAN32',
              gearNotes: 'Perdix AI',
              issueNotes: 'None',
              endGF99: 0.85,
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);

        expect(dives, hasLength(1));
        final dive = dives.first;
        expect(dive.diveId, 'test-001');
        expect(dive.diveDate, '2025-06-15 10:30:00');
        expect(dive.depth, 26.8);
        expect(dive.averageDepth, 19.4);
        expect(dive.diveLengthTime, 1764);
        expect(dive.diveNumber, '23');
        expect(dive.serialNumber, '69FE56D7');
        expect(dive.location, 'Shark River, NJ');
        expect(dive.site, 'Maclearie Park');
        expect(dive.buddy, 'John Doe');
        expect(dive.notes, 'Great dive');
        expect(dive.environment, 'Ocean/Sea');
        expect(dive.visibility, '30');
        expect(dive.weather, 'Sunny');
        expect(dive.conditions, 'Current');
        expect(dive.airTemperature, '72');
        expect(dive.weight, '14');
        expect(dive.dress, 'Wet Suit');
        expect(dive.apparatus, 'Open Circuit');
        expect(dive.thermalComfort, 'Comfortable');
        expect(dive.workload, 'Light');
        expect(dive.gnssEntryLocation, '40.1234,-74.5678');
        expect(dive.gasNotes, 'EAN32');
        expect(dive.gearNotes, 'Perdix AI');
        expect(dive.issueNotes, 'None');
        expect(dive.endGF99, 0.85);
      });

      test('parses TankProfileData JSON string', () async {
        final tankJson = jsonEncode({
          'TankData': [
            {
              'GasProfile': {'O2Percent': 32, 'HePercent': 0},
              'DiveTransmitter': {'IsOn': true, 'Name': 'T1'},
            },
          ],
        });

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(
              diveId: 'tank-test',
              tankProfileDataJson: tankJson,
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.tankProfileData, isNotNull);
        expect(dives.first.tankProfileData!['TankData'], isList);
      });

      test('parses calculatedValues JSON string', () async {
        final calcJson = jsonEncode({'AverageDepth': 15.5, 'MaxDepth': 28.3});

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(
              diveId: 'calc-test',
              calculatedValuesJson: calcJson,
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.calculatedValues, isNotNull);
        expect(dives.first.calculatedValues!['AverageDepth'], 15.5);
      });

      test('decompresses gzip data_bytes_1', () async {
        final rawData = Uint8List.fromList(List.filled(256, 0xAB));
        final compressed = createCompressedLogData(rawData);

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'gz-test', dataBytes1: compressed),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.decompressedLogData, isNotNull);
        expect(dives.first.decompressedLogData!.length, rawData.length);
        expect(dives.first.decompressedLogData, equals(rawData));
      });

      test(
        'decompresses gzip with zeroed CRC via raw deflate fallback',
        () async {
          final rawData = Uint8List.fromList(List.filled(256, 0xCD));
          final compressed = createCompressedLogDataWithZeroedCrc(rawData);

          final bytes = createShearwaterTestDb(
            dives: [
              ShearwaterTestDive(diveId: 'crc-test', dataBytes1: compressed),
            ],
          );

          final dives = await ShearwaterDbReader.readDives(bytes);
          expect(dives.first.decompressedLogData, isNotNull);
          expect(dives.first.decompressedLogData!.length, rawData.length);
          expect(dives.first.decompressedLogData, equals(rawData));
        },
      );

      test('returns null for data_bytes_1 that is too short', () async {
        // 4 prefix + 10 gzip header = 14 minimum; use 10 bytes
        final tooShort = Uint8List.fromList(List.filled(10, 0));

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'short-test', dataBytes1: tooShort),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.decompressedLogData, isNull);
      });

      test('returns null for completely invalid data_bytes_1', () async {
        // Long enough but not valid gzip
        final invalid = Uint8List.fromList(List.filled(100, 0xFF));

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'invalid-test', dataBytes1: invalid),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.decompressedLogData, isNull);
      });

      test('parses header JSON from data_bytes_2', () async {
        final headerJson = {'SomeHeader': 'value', 'Version': 42};
        final headerBlob = jsonToBlob(headerJson);

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'hdr-test', dataBytes2: headerBlob),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.headerJson, isNotNull);
        expect(dives.first.headerJson!['SomeHeader'], 'value');
        expect(dives.first.headerJson!['Version'], 42);
      });

      test('parses footer JSON from data_bytes_3', () async {
        final footerJson = {'UnitSystem': 1, 'DiveTimeInSeconds': 1764};
        final footerBlob = jsonToBlob(footerJson);

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'ftr-test', dataBytes3: footerBlob),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.footerJson, isNotNull);
        expect(dives.first.footerJson!['UnitSystem'], 1);
        expect(dives.first.footerJson!['DiveTimeInSeconds'], 1764);
      });

      test('normalizes empty strings to null', () async {
        final bytes = createShearwaterTestDb(
          dives: [
            const ShearwaterTestDive(
              diveId: 'empty-str',
              diveDate: '',
              location: '',
              site: '',
              buddy: '',
              notes: '',
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        final dive = dives.first;
        // Empty strings should be normalized to null by _str()
        expect(dive.diveDate, isNull);
        expect(dive.location, isNull);
        expect(dive.site, isNull);
        expect(dive.buddy, isNull);
        expect(dive.notes, isNull);
      });

      test('handles null values gracefully', () async {
        final bytes = createShearwaterTestDb(
          dives: [const ShearwaterTestDive(diveId: 'nulls')],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        final dive = dives.first;
        expect(dive.diveId, 'nulls');
        expect(dive.depth, isNull);
        expect(dive.averageDepth, isNull);
        expect(dive.diveLengthTime, isNull);
        expect(dive.decompressedLogData, isNull);
        expect(dive.headerJson, isNull);
        expect(dive.footerJson, isNull);
        expect(dive.tankProfileData, isNull);
        expect(dive.calculatedValues, isNull);
      });

      test('reads multiple dives ordered by date', () async {
        final bytes = createShearwaterTestDb(
          dives: [
            const ShearwaterTestDive(
              diveId: 'dive-2',
              diveDate: '2025-06-16 09:00:00',
            ),
            const ShearwaterTestDive(
              diveId: 'dive-1',
              diveDate: '2025-06-15 10:00:00',
            ),
            const ShearwaterTestDive(
              diveId: 'dive-3',
              diveDate: '2025-06-17 08:00:00',
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives, hasLength(3));
        expect(dives[0].diveId, 'dive-1');
        expect(dives[1].diveId, 'dive-2');
        expect(dives[2].diveId, 'dive-3');
      });

      test('handles dive with log_data filename', () async {
        final bytes = createShearwaterTestDb(
          dives: [
            const ShearwaterTestDive(
              diveId: 'fn-test',
              fileName: 'Teric[69FE56D7]#23 2025-12-27 14-01-08.swlogzp',
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.fileName, contains('Teric'));
        expect(dives.first.fileName, contains('.swlogzp'));
      });

      test('handles invalid JSON in TankProfileData gracefully', () async {
        final bytes = createShearwaterTestDb(
          dives: [
            const ShearwaterTestDive(
              diveId: 'bad-json',
              tankProfileDataJson: 'not valid json {{{',
            ),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.tankProfileData, isNull);
      });

      test('handles invalid JSON in data_bytes_2 gracefully', () async {
        final invalidBlob = Uint8List.fromList(utf8.encode('not json'));

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'bad-hdr', dataBytes2: invalidBlob),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.headerJson, isNull);
      });

      test('handles empty BLOB in data_bytes_3 gracefully', () async {
        final emptyBlob = Uint8List(0);

        final bytes = createShearwaterTestDb(
          dives: [
            ShearwaterTestDive(diveId: 'empty-blob', dataBytes3: emptyBlob),
          ],
        );

        final dives = await ShearwaterDbReader.readDives(bytes);
        expect(dives.first.footerJson, isNull);
      });
    });

    group('real fixture', () {
      late Uint8List dbBytes;

      setUpAll(() {
        final file = File('third_party/shearwater_cloud_database.db');
        if (!file.existsSync()) return;
        dbBytes = file.readAsBytesSync();
      });

      test('reads 28 dives from real Shearwater Cloud database', () async {
        final file = File('third_party/shearwater_cloud_database.db');
        if (!file.existsSync()) {
          markTestSkipped('Fixture not available');
          return;
        }
        final dives = await ShearwaterDbReader.readDives(dbBytes);
        expect(dives, hasLength(28));
      });

      test('real dives have decompressed log data', () async {
        final file = File('third_party/shearwater_cloud_database.db');
        if (!file.existsSync()) {
          markTestSkipped('Fixture not available');
          return;
        }
        final dives = await ShearwaterDbReader.readDives(dbBytes);
        final withData = dives
            .where((d) => d.decompressedLogData != null)
            .toList();
        expect(withData, isNotEmpty);
      });
    });
  });
}
