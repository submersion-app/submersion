import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';

void main() {
  late Uint8List dbBytes;

  setUpAll(() {
    final file = File('third_party/shearwater_cloud_database.db');
    if (!file.existsSync()) {
      fail('Test fixture not found: third_party/shearwater_cloud_database.db');
    }
    dbBytes = file.readAsBytesSync();
  });

  group('ShearwaterCloudParser', () {
    test('supportedFormats includes shearwaterDb', () {
      final parser = ShearwaterCloudParser();
      expect(parser.supportedFormats, contains(ImportFormat.shearwaterDb));
    });

    test('parse returns payload with 28 dives', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      expect(payload.isNotEmpty, isTrue);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(28));
    });

    test('parse includes sites', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, isNotEmpty);
    });

    test('dive entities have required fields', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final dive = dives.firstWhere(
        (d) => d['importId'] == '1676633251758354277',
      );
      expect(dive['dateTime'], isA<DateTime>());
      expect(dive['maxDepth'], isA<double>());
      expect(dive['importSource'], 'shearwater_cloud');
      expect(dive['notes'], contains('PADI Open Water'));
    });

    test('parse returns empty payload for non-Shearwater bytes', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(Uint8List.fromList([1, 2, 3]));
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });

    test('metadata contains source and dive count', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      expect(payload.metadata['source'], 'shearwater_cloud');
      expect(payload.metadata['diveCount'], 28);
    });
  });
}
