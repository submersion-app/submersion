import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('built-in presets', () {
    test('contains exactly 7 presets', () {
      expect(builtInCsvPresets.length, 7);
    });

    test('all presets have unique IDs', () {
      final ids = builtInCsvPresets.map((p) => p.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length);
    });

    test('all presets have signature headers', () {
      for (final preset in builtInCsvPresets) {
        expect(
          preset.signatureHeaders,
          isNotEmpty,
          reason: '${preset.name} has no signature headers',
        );
      }
    });

    test('all presets have at least one mapping', () {
      for (final preset in builtInCsvPresets) {
        expect(
          preset.mappings,
          isNotEmpty,
          reason: '${preset.name} has no mappings',
        );
      }
    });

    test('Subsurface preset is multi-file with 2 roles', () {
      final subsurface = builtInCsvPresets.firstWhere(
        (p) => p.id == 'subsurface',
      );
      expect(subsurface.isMultiFile, isTrue);
      expect(subsurface.fileRoles.length, 2);
    });

    test('Subsurface preset maps all 6 tank groups', () {
      final subsurface = builtInCsvPresets.firstWhere(
        (p) => p.id == 'subsurface',
      );
      final primaryMapping = subsurface.mappings['dive_list'];
      expect(primaryMapping, isNotNull);
      final targetFields = primaryMapping!.columns.map((c) => c.targetField);
      for (var i = 1; i <= 6; i++) {
        expect(
          targetFields,
          contains('tankVolume_$i'),
          reason: 'Missing tankVolume_$i',
        );
        expect(
          targetFields,
          contains('startPressure_$i'),
          reason: 'Missing startPressure_$i',
        );
        expect(
          targetFields,
          contains('endPressure_$i'),
          reason: 'Missing endPressure_$i',
        );
        expect(
          targetFields,
          contains('o2Percent_$i'),
          reason: 'Missing o2Percent_$i',
        );
        expect(
          targetFields,
          contains('hePercent_$i'),
          reason: 'Missing hePercent_$i',
        );
      }
    });

    test('all presets are builtIn source', () {
      for (final preset in builtInCsvPresets) {
        expect(
          preset.source,
          PresetSource.builtIn,
          reason: '${preset.name} is not builtIn',
        );
      }
    });

    group('CsvPreset serialization roundtrip for user presets', () {
      test('toJson produces valid JSON string', () {
        const preset = CsvPreset(
          id: 'user-test-1',
          name: 'My Custom Preset',
          source: PresetSource.userSaved,
          sourceApp: SourceApp.macdive,
          signatureHeaders: ['Dive No', 'Date', 'Max. Depth'],
          matchThreshold: 0.6,
          mappings: {
            'primary': FieldMapping(
              name: 'Primary',
              columns: [
                ColumnMapping(
                  sourceColumn: 'Dive No',
                  targetField: 'diveNumber',
                ),
                ColumnMapping(
                  sourceColumn: 'Max. Depth',
                  targetField: 'maxDepth',
                  transform: ValueTransform.feetToMeters,
                ),
              ],
            ),
          },
          supportedEntities: {ImportEntityType.dives},
        );

        final json = preset.toJson();
        expect(() => jsonDecode(json), returnsNormally);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['id'], 'user-test-1');
        expect(decoded['name'], 'My Custom Preset');
        expect(decoded['sourceApp'], 'macdive');
        expect(decoded['signatureHeaders'], ['Dive No', 'Date', 'Max. Depth']);
        expect(decoded['matchThreshold'], 0.6);
      });

      test('fromJson reconstructs a matching preset', () {
        const original = CsvPreset(
          id: 'user-roundtrip',
          name: 'Roundtrip Test',
          source: PresetSource.userSaved,
          sourceApp: SourceApp.generic,
          signatureHeaders: ['Date', 'Max Depth', 'Duration'],
          matchThreshold: 0.65,
          mappings: {
            'primary': FieldMapping(
              name: 'Primary',
              columns: [
                ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
                ColumnMapping(
                  sourceColumn: 'Max Depth',
                  targetField: 'maxDepth',
                  transform: ValueTransform.feetToMeters,
                ),
                ColumnMapping(
                  sourceColumn: 'Duration',
                  targetField: 'duration',
                  transform: ValueTransform.minutesToSeconds,
                ),
              ],
            ),
          },
          expectedUnits: UnitSystem.imperial,
          supportedEntities: {ImportEntityType.dives, ImportEntityType.sites},
        );

        final json = original.toJson();
        final restored = CsvPreset.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.source, PresetSource.userSaved);
        expect(restored.sourceApp, original.sourceApp);
        expect(restored.signatureHeaders, original.signatureHeaders);
        expect(restored.matchThreshold, original.matchThreshold);
        expect(restored.expectedUnits, original.expectedUnits);
        expect(restored.supportedEntities, original.supportedEntities);

        final restoredMapping = restored.mappings['primary'];
        expect(restoredMapping, isNotNull);
        expect(restoredMapping!.columns.length, 3);
        expect(
          restoredMapping.columns[1].transform,
          ValueTransform.feetToMeters,
        );
        expect(
          restoredMapping.columns[2].transform,
          ValueTransform.minutesToSeconds,
        );
      });

      test('fromJson sets source to userSaved regardless of JSON content', () {
        const preset = CsvPreset(
          id: 'test',
          name: 'Test',
          source: PresetSource.builtIn,
          signatureHeaders: ['Date'],
          mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
        );

        final json = preset.toJson();
        final restored = CsvPreset.fromJson(json);
        expect(restored.source, PresetSource.userSaved);
      });

      test('toJson roundtrips null optional fields gracefully', () {
        const preset = CsvPreset(
          id: 'minimal',
          name: 'Minimal',
          signatureHeaders: ['Date'],
          mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
        );

        final json = preset.toJson();
        final restored = CsvPreset.fromJson(json);

        expect(restored.sourceApp, isNull);
        expect(restored.expectedUnits, isNull);
        expect(restored.expectedTimeFormat, isNull);
      });
    });
  });
}
