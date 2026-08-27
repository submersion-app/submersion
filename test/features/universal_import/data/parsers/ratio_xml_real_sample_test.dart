import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/ratio_xml_parser.dart';

void main() {
  group('RatioXmlParser real-sample regression', () {
    test('parses a complete real-world iX3M export seamlessly', () async {
      final file = File(
        'test/fixtures/universal_import/ratio_xml/IX3M_2_PRO_123456-dive_14-19880731_190154.xml',
      );
      final bytes = await file.readAsBytes();

      const parser = RatioXmlParser();
      final payload = await parser.parse(
        bytes,
        options: const ImportOptions(
          sourceApp: SourceApp.ratio,
          format: ImportFormat.ratioXml,
          fileName: 'IX3M_2_PRO_123456-dive_14-19880731_190154.xml',
        ),
      );

      // Verify overall payload structure
      expect(payload.warnings, isEmpty);
      expect(payload.metadata['source'], 'ratio_xml');
      expect(payload.metadata['computerModel'], 'IX3M 2 PRO');
      expect(payload.metadata['computerSerial'], '123456');

      final dives = payload.entities[ImportEntityType.dives]!;
      expect(dives, hasLength(1));

      final dive = dives.single;

      // Verify basic metadata
      expect(dive['diveComputerModel'], 'IX3M 2 PRO');
      expect(dive['diveComputerSerial'], '123456');
      expect(dive['diveNumber'], 14);

      // Verify time and duration (assuming UTCStartingTimeS converts to this UTC time)
      expect(dive['dateTime'], DateTime.utc(2026, 7, 31, 17, 1, 54));

      // Verify unit assumptions are strictly followed
      // depthMax = 1329 cm -> 13.29 m
      expect(dive['maxDepth'], closeTo(13.29, 0.01));
      // avgDepth = 748 cm -> 7.48 m
      expect(dive['avgDepth'], closeTo(7.48, 0.01));
      // surfacePressureMbar = 870 hPa to 1086 hPa
      expect(dive['surfacePressure'], closeTo(1.0019, 0.0001));

      // Verify environment
      expect(dive['waterType'], 'fresh');
      expect(dive['surfaceInterval'], const Duration(seconds: 2935));

      // Verify tanks
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      expect(tanks[0]['startPressure'], 128.0);
      expect(tanks[0]['gasMix'].o2, 21.0);
      expect(tanks[0]['gasMix'].he, 0.0);

      // Verify profile length
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile, hasLength(274));

      // Verify first sample structure
      expect(profile.first['timestamp'], 10);
      expect(profile.first['depth'], closeTo(2.5, 0.1)); // 25 dm -> 2.5m
      expect(
        profile.first['temperature'],
        closeTo(25.2, 0.1),
      ); // 252 dC -> 25.2C

      final pressures = profile.first['allTankPressures'] as List;
      expect(pressures, hasLength(1));
      expect(pressures.first['tankIndex'], 0);
      expect(pressures.first['pressure'], 128.0);
    });
  });
}
