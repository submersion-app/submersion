import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/field_mapping_engine.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

void main() {
  const engine = FieldMappingEngine();

  group('presetFor', () {
    test('returns MacDive preset', () {
      final preset = engine.presetFor(SourceApp.macdive);
      expect(preset, isNotNull);
      expect(preset!.name, 'MacDive');
      expect(preset.sourceApp, SourceApp.macdive);
      expect(preset.columns, isNotEmpty);
    });

    test('returns Diving Log preset', () {
      final preset = engine.presetFor(SourceApp.divingLog);
      expect(preset, isNotNull);
      expect(preset!.name, 'Diving Log');
    });

    test('returns DiveMate preset', () {
      final preset = engine.presetFor(SourceApp.diveMate);
      expect(preset, isNotNull);
      expect(preset!.name, 'DiveMate');
    });

    test('returns Subsurface CSV preset', () {
      final preset = engine.presetFor(SourceApp.subsurface);
      expect(preset, isNotNull);
      expect(preset!.name, 'Subsurface CSV');
    });

    test('returns Garmin Connect preset', () {
      final preset = engine.presetFor(SourceApp.garminConnect);
      expect(preset, isNotNull);
      expect(preset!.name, 'Garmin Connect');
    });

    test('returns Shearwater preset', () {
      final preset = engine.presetFor(SourceApp.shearwater);
      expect(preset, isNotNull);
      expect(preset!.name, 'Shearwater Cloud');
    });

    test('returns Submersion preset', () {
      final preset = engine.presetFor(SourceApp.submersion);
      expect(preset, isNotNull);
      expect(preset!.name, 'Submersion');
    });

    test('returns null for generic', () {
      expect(engine.presetFor(SourceApp.generic), isNull);
    });

    test('returns null for SSI', () {
      expect(engine.presetFor(SourceApp.ssiMyDiveGuide), isNull);
    });
  });

  group('autoMap with sourceApp preset', () {
    test('MacDive preset matches all known columns', () {
      final headers = [
        'Dive No',
        'Date',
        'Time',
        'Location',
        'Max. Depth',
        'Avg. Depth',
        'Bottom Time',
        'Water Temp',
        'Air Temp',
        'Visibility',
        'Dive Type',
        'Rating',
        'Notes',
        'Buddy',
        'Dive Master',
      ];
      final mapping = engine.autoMap(headers, sourceApp: SourceApp.macdive);
      expect(mapping.columns.length, 15);
      expect(mapping.name, contains('MacDive'));
    });

    test('MacDive preset filters to only matching columns', () {
      final headers = ['Dive No', 'Date', 'Unknown Column'];
      final mapping = engine.autoMap(headers, sourceApp: SourceApp.macdive);
      expect(mapping.columns.length, 2);
    });

    test('falls back to generic when no preset columns match', () {
      final headers = ['Column A', 'Column B'];
      final mapping = engine.autoMap(headers, sourceApp: SourceApp.macdive);
      expect(mapping.name, 'Auto-detected');
      expect(mapping.sourceApp, SourceApp.generic);
    });

    test('Subsurface preset includes HMS transform for duration', () {
      final headers = ['date', 'time', 'duration', 'maxdepth'];
      final mapping = engine.autoMap(headers, sourceApp: SourceApp.subsurface);
      final durationCol = mapping.columns.firstWhere(
        (c) => c.targetField == 'duration',
      );
      expect(durationCol.transform, ValueTransform.hmsToSeconds);
    });
  });

  group('autoMap generic (no sourceApp)', () {
    test('maps standard dive columns by keyword', () {
      final headers = [
        'Dive Number',
        'Date',
        'Time',
        'Max Depth',
        'Duration',
        'Water Temp',
        'Site Name',
        'Notes',
        'Rating',
      ];
      final mapping = engine.autoMap(headers);
      expect(mapping.name, 'Auto-detected');
      expect(mapping.sourceApp, SourceApp.generic);

      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('diveNumber'));
      expect(targetFields, contains('date'));
      expect(targetFields, contains('time'));
      expect(targetFields, contains('maxDepth'));
      expect(targetFields, contains('duration'));
      expect(targetFields, contains('waterTemp'));
      expect(targetFields, contains('siteName'));
      expect(targetFields, contains('notes'));
      expect(targetFields, contains('rating'));
    });

    test('maps avg depth header', () {
      final mapping = engine.autoMap(['Avg Depth']);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('avgDepth'));
    });

    test('maps buddy and dive master headers', () {
      final mapping = engine.autoMap(['Buddy', 'Dive Master']);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('buddy'));
      expect(targetFields, contains('diveMaster'));
    });

    test('maps visibility header', () {
      final mapping = engine.autoMap(['Visibility']);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('visibility'));
    });

    test('maps pressure headers', () {
      final mapping = engine.autoMap([
        'Start Pressure',
        'End Pressure',
        'Tank Volume',
      ]);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('startPressure'));
      expect(targetFields, contains('endPressure'));
      expect(targetFields, contains('tankVolume'));
    });

    test('maps O2 header', () {
      final mapping = engine.autoMap(['O2 %']);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('o2Percent'));
    });

    test('skips unrecognized columns', () {
      final mapping = engine.autoMap(['Random Header', 'Another One']);
      expect(mapping.columns, isEmpty);
    });

    test('date header not confused with datetime', () {
      final mapping = engine.autoMap(['Date', 'Time']);
      final targetFields = mapping.columns.map((c) => c.targetField).toSet();
      expect(targetFields, contains('date'));
      expect(targetFields, contains('time'));
    });

    test('time header not confused with bottom time or duration', () {
      final mapping = engine.autoMap(['Time', 'Bottom Time', 'Duration']);
      final targets = mapping.columns.map((c) => c.targetField).toList();
      expect(targets, contains('time'));
      expect(targets, contains('duration'));
      // 'Bottom Time' should also map to duration
    });
  });

  group('suggestTransforms', () {
    test('suggests ft->m for depth with large values', () {
      final mappings = [
        const ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
      ];
      final headers = ['Depth'];
      final sampleRows = [
        ['100'],
        ['130'],
        ['110'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, ValueTransform.feetToMeters);
    });

    test('suggests F->C for temperature with large values', () {
      final mappings = [
        const ColumnMapping(
          sourceColumn: 'Water Temp',
          targetField: 'waterTemp',
        ),
      ];
      final headers = ['Water Temp'];
      final sampleRows = [
        ['72'],
        ['68'],
        ['75'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, ValueTransform.fahrenheitToCelsius);
    });

    test('suggests psi->bar for pressure with large values', () {
      final mappings = [
        const ColumnMapping(
          sourceColumn: 'Start',
          targetField: 'startPressure',
        ),
      ];
      final headers = ['Start'];
      final sampleRows = [
        ['3000'],
        ['2800'],
        ['3200'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, ValueTransform.psiToBar);
    });

    test('preserves existing transform', () {
      final mappings = [
        const ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
      ];
      final headers = ['Duration'];
      final sampleRows = [
        ['45'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, ValueTransform.minutesToSeconds);
    });

    test('no suggestion when values look metric', () {
      final mappings = [
        const ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
      ];
      final headers = ['Depth'];
      final sampleRows = [
        ['25'],
        ['30'],
        ['18'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, isNull);
    });

    test('handles missing column in sample rows', () {
      final mappings = [
        const ColumnMapping(sourceColumn: 'Missing', targetField: 'maxDepth'),
      ];
      final headers = ['Other'];
      final sampleRows = [
        ['25'],
      ];

      final result = engine.suggestTransforms(mappings, headers, sampleRows);
      expect(result.first.transform, isNull);
    });
  });

  group('Preset column counts', () {
    test('MacDive preset has 15 columns', () {
      final preset = engine.presetFor(SourceApp.macdive)!;
      expect(preset.columns.length, 15);
    });

    test('Submersion preset has 15 columns', () {
      final preset = engine.presetFor(SourceApp.submersion)!;
      expect(preset.columns.length, 15);
    });

    test('Garmin Connect preset has 6 columns', () {
      final preset = engine.presetFor(SourceApp.garminConnect)!;
      expect(preset.columns.length, 6);
    });

    test('Shearwater preset has 8 columns', () {
      final preset = engine.presetFor(SourceApp.shearwater)!;
      expect(preset.columns.length, 8);
    });
  });

  group('MacDive preset transforms', () {
    test('Bottom Time has minutesToSeconds transform', () {
      final preset = engine.presetFor(SourceApp.macdive)!;
      final bottomTime = preset.columns.firstWhere(
        (c) => c.sourceColumn == 'Bottom Time',
      );
      expect(bottomTime.transform, ValueTransform.minutesToSeconds);
    });

    test('Visibility has visibilityScale transform', () {
      final preset = engine.presetFor(SourceApp.macdive)!;
      final vis = preset.columns.firstWhere(
        (c) => c.sourceColumn == 'Visibility',
      );
      expect(vis.transform, ValueTransform.visibilityScale);
    });

    test('Rating has ratingScale transform', () {
      final preset = engine.presetFor(SourceApp.macdive)!;
      final rating = preset.columns.firstWhere(
        (c) => c.sourceColumn == 'Rating',
      );
      expect(rating.transform, ValueTransform.ratingScale);
    });
  });
}
