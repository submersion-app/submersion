import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

void main() {
  late Uint8List dbBytes;

  setUpAll(() {
    final file = File('third_party/shearwater_cloud_database.db');
    if (!file.existsSync()) {
      fail('Test fixture not found: third_party/shearwater_cloud_database.db');
    }
    dbBytes = file.readAsBytesSync();
  });

  group('ShearwaterDbReader', () {
    test('isShearwaterCloudDb returns true for valid database', () async {
      final result = await ShearwaterDbReader.isShearwaterCloudDb(dbBytes);
      expect(result, isTrue);
    });

    test('isShearwaterCloudDb returns false for non-SQLite bytes', () async {
      final result = await ShearwaterDbReader.isShearwaterCloudDb(
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(result, isFalse);
    });

    test('readDives returns all dives from database', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      expect(dives, hasLength(28));
    });

    test('dive has metadata from dive_details', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.firstWhere((d) => d.diveId == '1676633251758354277');
      expect(dive.location, 'Shark River, NJ, USA');
      expect(dive.site, 'Maclearie Park');
      expect(dive.buddy, 'Kiyan Griffin');
      expect(dive.notes, 'PADI Open Water certification dive 1');
      expect(dive.environment, 'Ocean/Sea');
    });

    test('dive has binary data decompressed from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.decompressedLogData, isNotNull);
      expect(dive.decompressedLogData, isNotEmpty);
    });

    test('dive has filename from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.fileName, contains('Teric'));
      expect(dive.fileName, contains('.swlogzp'));
    });

    test('dive has TankProfileData parsed as JSON', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.tankProfileData, isNotNull);
      expect(dive.tankProfileData!['GasProfiles'], isList);
      expect(dive.tankProfileData!['TankData'], isList);
    });

    test('dive has calculatedValues from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.calculatedValues, isNotNull);
      expect(dive.calculatedValues!['AverageDepth'], isA<num>());
    });

    test('dive has footer JSON from data_bytes_3', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.footerJson, isNotNull);
      expect(dive.footerJson!['UnitSystem'], isA<int>());
      expect(dive.footerJson!['DiveTimeInSeconds'], isA<int>());
    });
  });
}
