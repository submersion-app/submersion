import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';

import '../services/shearwater_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShearwaterCloudParser', () {
    test('supportedFormats includes shearwaterDb', () {
      final parser = ShearwaterCloudParser();
      expect(parser.supportedFormats, contains(ImportFormat.shearwaterDb));
    });

    test('parse returns error for non-Shearwater bytes', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(Uint8List.fromList([1, 2, 3]));
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('parse returns info warning for empty database', () async {
      final parser = ShearwaterCloudParser();
      final bytes = createShearwaterTestDb();
      final payload = await parser.parse(bytes);
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.first.severity, ImportWarningSeverity.info);
      expect(payload.warnings.first.message, contains('no dives'));
    });

    test('parse returns dives from synthetic database', () async {
      final tankJson = jsonEncode({
        'TankData': [
          {
            'StartPressurePSI': '3000',
            'EndPressurePSI': '1500',
            'GasProfile': {'O2Percent': 32, 'HePercent': 0},
            'DiveTransmitter': {'IsOn': true, 'Name': 'T1'},
            'SurfacePressureMBar': 1013.0,
          },
        ],
      });
      final footerBlob = jsonToBlob({
        'UnitSystem': 0,
        'DiveTimeInSeconds': 3600,
      });

      final bytes = createShearwaterTestDb(
        dives: [
          ShearwaterTestDive(
            diveId: 'synth-001',
            diveDate: '2025-06-15 10:30:00',
            depth: 25.0,
            averageDepth: 18.0,
            diveLengthTime: 3600,
            diveNumber: '1',
            site: 'Test Reef',
            location: 'Test Location',
            environment: 'Ocean/Sea',
            weather: 'Sunny',
            fileName: 'Teric[AABB1234]#1 2025-06-15 10-30-00.swlogzp',
            tankProfileDataJson: tankJson,
            dataBytes3: footerBlob,
          ),
          ShearwaterTestDive(
            diveId: 'synth-002',
            diveDate: '2025-06-16 09:00:00',
            depth: 18.0,
            averageDepth: 12.0,
            diveLengthTime: 2400,
            diveNumber: '2',
            site: 'Test Reef',
            location: 'Test Location',
            environment: 'Lake',
            fileName: 'Teric[AABB1234]#2 2025-06-16 09-00-00.swlogzp',
            dataBytes3: footerBlob,
          ),
        ],
      );

      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        bytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      expect(payload.isNotEmpty, isTrue);

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(2));
      expect(dives[0]['importSource'], 'shearwater_cloud');
      expect(dives[0]['importId'], 'synth-001');
      expect(dives[0]['dateTime'], isA<DateTime>());
      expect(dives[0]['maxDepth'], 25.0);
      expect(dives[0]['siteName'], 'Test Reef');
    });

    test('parse extracts unique sites', () async {
      final bytes = createShearwaterTestDb(
        dives: [
          const ShearwaterTestDive(
            diveId: 'site-1',
            diveDate: '2025-06-15',
            site: 'Reef A',
            location: 'FL',
            gnssEntryLocation: '25.0,-80.0',
          ),
          const ShearwaterTestDive(
            diveId: 'site-2',
            diveDate: '2025-06-16',
            site: 'Reef A',
            location: 'FL',
          ),
          const ShearwaterTestDive(
            diveId: 'site-3',
            diveDate: '2025-06-17',
            site: 'Reef B',
          ),
        ],
      );

      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(bytes);

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(2));
      final names = sites.map((s) => s['name']).toSet();
      expect(names, containsAll(['Reef A', 'Reef B']));
    });

    test('metadata contains source and dive count', () async {
      final bytes = createShearwaterTestDb(
        dives: [
          const ShearwaterTestDive(diveId: 'd1', diveDate: '2025-01-01'),
          const ShearwaterTestDive(diveId: 'd2', diveDate: '2025-01-02'),
        ],
      );

      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(bytes);

      expect(payload.metadata['source'], 'shearwater_cloud');
      expect(payload.metadata['diveCount'], 2);
    });

    test('FFI failure produces single warning then falls back', () async {
      final rawData = Uint8List.fromList(List.filled(100, 0));
      final compressed = createCompressedLogData(rawData);

      final bytes = createShearwaterTestDb(
        dives: [
          ShearwaterTestDive(
            diveId: 'ffi-1',
            diveDate: '2025-01-01',
            fileName: 'Teric[AABB1234]#1 2025-01-01 10-00-00.swlogzp',
            dataBytes1: compressed,
          ),
          ShearwaterTestDive(
            diveId: 'ffi-2',
            diveDate: '2025-01-02',
            fileName: 'Teric[AABB1234]#2 2025-01-02 10-00-00.swlogzp',
            dataBytes1: compressed,
          ),
          ShearwaterTestDive(
            diveId: 'ffi-3',
            diveDate: '2025-01-03',
            fileName: 'Teric[AABB1234]#3 2025-01-03 10-00-00.swlogzp',
            dataBytes1: compressed,
          ),
        ],
      );

      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(bytes);

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(3));
      // MissingPluginException is caught by the parser on the first dive,
      // FFI is disabled, and remaining dives use metadata-only.
      // No per-dive "Profile parsing failed" warnings should appear.
      final ffiWarnings = payload.warnings.where(
        (w) => w.message.contains('Profile parsing failed'),
      );
      expect(ffiWarnings, isEmpty);
    });

    group('real fixture', () {
      test('parses 28 dives from real database', () async {
        final file = File('third_party/shearwater_cloud_database.db');
        if (!file.existsSync()) {
          markTestSkipped('Fixture not available');
          return;
        }
        final dbBytes = file.readAsBytesSync();
        final parser = ShearwaterCloudParser();
        final payload = await parser.parse(
          dbBytes,
          options: const ImportOptions(
            sourceApp: SourceApp.shearwater,
            format: ImportFormat.shearwaterDb,
          ),
        );
        final dives = payload.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(28));
      });
    });
  });
}
