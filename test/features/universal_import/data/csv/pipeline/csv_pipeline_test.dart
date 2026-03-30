import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Build an [ImportConfiguration] from a detected preset for testing.
///
/// This replicates the output the Configure stage (Task 3) would produce
/// when a preset is already known.
ImportConfiguration _configFromPreset(CsvPreset preset) {
  return ImportConfiguration(
    mappings: preset.mappings,
    entityTypesToImport: preset.supportedEntities,
    sourceApp: preset.sourceApp,
    preset: preset,
  );
}

void main() {
  late CsvPipeline pipeline;

  setUp(() {
    pipeline = CsvPipeline();
  });

  group('CsvPipeline', () {
    test('detects Subsurface from real headers', () {
      // Headers taken from a real Subsurface dive list CSV export.
      const csvContent =
          'dive number,date,time,duration [min],maxdepth [m],'
          'avgdepth [m],mode,airtemp [C],watertemp [C],'
          'cylinder size (1) [l],startpressure (1) [bar],'
          'endpressure (1) [bar],o2 (1) [%],he (1) [%],'
          'location,gps,divemaster,buddy,suit,rating,'
          'visibility,notes,weight [kg],tags,sac [l/min]\n'
          '1,2024-06-15,09:00,45,25.0,18.0,OC,28.0,27.0,'
          '12.0,200,50,21,0,Blue Hole,,,,,5,good,'
          'Saw a turtle,2.0,reef,14.5\n';

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);

      expect(detected.isDetected, isTrue);
      expect(detected.sourceApp, equals(SourceApp.subsurface));
    });

    test('full pipeline produces ImportPayload with dives', () {
      // Two-row Subsurface dive list CSV.
      const csvContent =
          'dive number,date,time,duration [min],maxdepth [m],'
          'avgdepth [m],mode,airtemp [C],watertemp [C],'
          'cylinder size (1) [l],startpressure (1) [bar],'
          'endpressure (1) [bar],o2 (1) [%],he (1) [%],'
          'location,gps,divemaster,buddy,suit,rating,'
          'visibility,notes,weight [kg],tags,sac [l/min]\n'
          '1,2024-06-15,09:00,45,25.0,18.0,OC,28.0,27.0,'
          '12.0,200,50,21,0,Blue Hole,,,,,5,good,'
          'Saw a turtle,2.0,reef,14.5\n'
          '2,2024-06-16,10:00,50,30.0,22.0,OC,28.0,26.5,'
          '12.0,200,60,21,0,The Wall,,,,,4,good,'
          ',2.0,,15.0\n';

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);

      expect(detected.isDetected, isTrue);
      expect(detected.matchedPreset, isNotNull);

      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(2));

      // Each dive should have a generated UUID.
      for (final dive in dives) {
        expect(dive['id'], isNotNull);
        expect(dive['id'], isA<String>());
        expect((dive['id'] as String).isNotEmpty, isTrue);
      }

      // Sites should be extracted and deduplicated.
      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.length, greaterThanOrEqualTo(1));
    });
  });
}
