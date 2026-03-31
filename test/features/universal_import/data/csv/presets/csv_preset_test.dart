import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  // ======================== toJson / fromJson roundtrip ========================

  group('toJson / fromJson roundtrip with all fields populated', () {
    test('preserves all scalar fields', () {
      const original = CsvPreset(
        id: 'roundtrip-full',
        name: 'Full Roundtrip Preset',
        source: PresetSource.userSaved,
        sourceApp: SourceApp.subsurface,
        signatureHeaders: ['dive number', 'date', 'time', 'maxdepth [m]'],
        matchThreshold: 0.75,
        fileRoles: [],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary Mapping',
            sourceApp: SourceApp.subsurface,
            columns: [
              ColumnMapping(
                sourceColumn: 'dive number',
                targetField: 'diveNumber',
              ),
              ColumnMapping(sourceColumn: 'date', targetField: 'date'),
            ],
          ),
        },
        expectedUnits: UnitSystem.metric,
        expectedTimeFormat: ExpectedTimeFormat.h24,
        supportedEntities: {
          ImportEntityType.dives,
          ImportEntityType.sites,
          ImportEntityType.buddies,
        },
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
      expect(restored.expectedTimeFormat, original.expectedTimeFormat);
      expect(restored.supportedEntities, original.supportedEntities);
    });

    test('preserves mapping names and column count', () {
      const original = CsvPreset(
        id: 'roundtrip-mappings',
        name: 'Mapping Roundtrip',
        source: PresetSource.userSaved,
        signatureHeaders: ['Date'],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary',
            sourceApp: SourceApp.macdive,
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Max. Depth',
                targetField: 'maxDepth',
                transform: ValueTransform.feetToMeters,
              ),
              ColumnMapping(
                sourceColumn: 'Duration',
                targetField: 'duration',
                transform: ValueTransform.minutesToSeconds,
                defaultValue: '0',
              ),
            ],
          ),
          'secondary': FieldMapping(
            name: 'Secondary',
            columns: [
              ColumnMapping(sourceColumn: 'Temp', targetField: 'waterTemp'),
            ],
          ),
        },
      );

      final json = original.toJson();
      final restored = CsvPreset.fromJson(json);

      expect(restored.mappings.length, 2);
      expect(restored.mappings.containsKey('primary'), isTrue);
      expect(restored.mappings.containsKey('secondary'), isTrue);

      final primary = restored.mappings['primary']!;
      expect(primary.name, 'Primary');
      expect(primary.sourceApp, SourceApp.macdive);
      expect(primary.columns.length, 3);

      final secondary = restored.mappings['secondary']!;
      expect(secondary.name, 'Secondary');
      expect(secondary.sourceApp, isNull);
      expect(secondary.columns.length, 1);
    });

    test('preserves column mapping transforms and default values', () {
      const original = CsvPreset(
        id: 'roundtrip-transforms',
        name: 'Transform Roundtrip',
        signatureHeaders: ['Depth', 'Temp', 'Pressure'],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary',
            columns: [
              ColumnMapping(
                sourceColumn: 'Depth',
                targetField: 'maxDepth',
                transform: ValueTransform.feetToMeters,
              ),
              ColumnMapping(
                sourceColumn: 'Temp',
                targetField: 'waterTemp',
                transform: ValueTransform.fahrenheitToCelsius,
                defaultValue: '72',
              ),
              ColumnMapping(
                sourceColumn: 'Pressure',
                targetField: 'startPressure',
                transform: ValueTransform.psiToBar,
              ),
              ColumnMapping(
                sourceColumn: 'Volume',
                targetField: 'tankVolume',
                transform: ValueTransform.cubicFeetToLiters,
              ),
              ColumnMapping(
                sourceColumn: 'Time',
                targetField: 'duration',
                transform: ValueTransform.hmsToSeconds,
              ),
            ],
          ),
        },
      );

      final json = original.toJson();
      final restored = CsvPreset.fromJson(json);

      final cols = restored.mappings['primary']!.columns;
      expect(cols[0].transform, ValueTransform.feetToMeters);
      expect(cols[0].defaultValue, isNull);
      expect(cols[1].transform, ValueTransform.fahrenheitToCelsius);
      expect(cols[1].defaultValue, '72');
      expect(cols[2].transform, ValueTransform.psiToBar);
      expect(cols[3].transform, ValueTransform.cubicFeetToLiters);
      expect(cols[4].transform, ValueTransform.hmsToSeconds);
    });

    test('toJson produces valid JSON', () {
      const preset = CsvPreset(
        id: 'json-valid',
        name: 'JSON Valid',
        signatureHeaders: ['A', 'B'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      final json = preset.toJson();
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('toJson omits null sourceApp, expectedUnits, expectedTimeFormat', () {
      const preset = CsvPreset(
        id: 'omit-nulls',
        name: 'Omit Nulls',
        signatureHeaders: ['A'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      final json = preset.toJson();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data.containsKey('sourceApp'), isFalse);
      expect(data.containsKey('expectedUnits'), isFalse);
      expect(data.containsKey('expectedTimeFormat'), isFalse);
    });

    test('toJson includes non-null optional fields', () {
      const preset = CsvPreset(
        id: 'include-optionals',
        name: 'Include Optionals',
        sourceApp: SourceApp.diveMate,
        expectedUnits: UnitSystem.imperial,
        expectedTimeFormat: ExpectedTimeFormat.h12,
        signatureHeaders: ['A'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      final json = preset.toJson();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['sourceApp'], 'diveMate');
      expect(data['expectedUnits'], 'imperial');
      expect(data['expectedTimeFormat'], 'h12');
    });

    test('roundtrips all ExpectedTimeFormat values', () {
      for (final format in ExpectedTimeFormat.values) {
        final preset = CsvPreset(
          id: 'time-format-${format.name}',
          name: 'Time Format ${format.name}',
          signatureHeaders: ['A'],
          expectedTimeFormat: format,
          mappings: const {
            'primary': FieldMapping(name: 'Primary', columns: []),
          },
        );

        final restored = CsvPreset.fromJson(preset.toJson());
        expect(
          restored.expectedTimeFormat,
          format,
          reason: 'Failed roundtrip for ExpectedTimeFormat.${format.name}',
        );
      }
    });

    test('roundtrips all UnitSystem values', () {
      for (final units in UnitSystem.values) {
        final preset = CsvPreset(
          id: 'unit-system-${units.name}',
          name: 'Unit System ${units.name}',
          signatureHeaders: const ['A'],
          expectedUnits: units,
          mappings: const {
            'primary': FieldMapping(name: 'Primary', columns: []),
          },
        );

        final restored = CsvPreset.fromJson(preset.toJson());
        expect(
          restored.expectedUnits,
          units,
          reason: 'Failed roundtrip for UnitSystem.${units.name}',
        );
      }
    });
  });

  // ======================== fromJson with minimal fields ========================

  group('fromJson with minimal fields', () {
    test('only id and name required, all others get defaults', () {
      final minimalJson = jsonEncode({
        'id': 'minimal-preset',
        'name': 'Minimal Preset',
      });

      final preset = CsvPreset.fromJson(minimalJson);

      expect(preset.id, 'minimal-preset');
      expect(preset.name, 'Minimal Preset');
      expect(preset.source, PresetSource.userSaved);
      expect(preset.sourceApp, isNull);
      expect(preset.signatureHeaders, isEmpty);
      expect(preset.matchThreshold, 0.6);
      expect(preset.mappings, isEmpty);
      expect(preset.expectedUnits, isNull);
      expect(preset.expectedTimeFormat, isNull);
      expect(preset.supportedEntities, {
        ImportEntityType.dives,
        ImportEntityType.sites,
      });
    });

    test('missing matchThreshold defaults to 0.6', () {
      final json = jsonEncode({'id': 'no-threshold', 'name': 'No Threshold'});

      final preset = CsvPreset.fromJson(json);
      expect(preset.matchThreshold, 0.6);
    });

    test('missing signatureHeaders defaults to empty list', () {
      final json = jsonEncode({'id': 'no-headers', 'name': 'No Headers'});

      final preset = CsvPreset.fromJson(json);
      expect(preset.signatureHeaders, isEmpty);
    });

    test('missing mappings defaults to empty map', () {
      final json = jsonEncode({'id': 'no-mappings', 'name': 'No Mappings'});

      final preset = CsvPreset.fromJson(json);
      expect(preset.mappings, isEmpty);
    });

    test('empty supportedEntities falls back to dives and sites', () {
      final json = jsonEncode({
        'id': 'empty-entities',
        'name': 'Empty Entities',
        'supportedEntities': <String>[],
      });

      final preset = CsvPreset.fromJson(json);
      expect(preset.supportedEntities, {
        ImportEntityType.dives,
        ImportEntityType.sites,
      });
    });

    test('missing supportedEntities falls back to dives and sites', () {
      final json = jsonEncode({
        'id': 'missing-entities',
        'name': 'Missing Entities',
      });

      final preset = CsvPreset.fromJson(json);
      expect(preset.supportedEntities, {
        ImportEntityType.dives,
        ImportEntityType.sites,
      });
    });

    test('fromJson always sets source to userSaved', () {
      // Even if the original was builtIn, fromJson should produce userSaved.
      const builtInPreset = CsvPreset(
        id: 'was-builtin',
        name: 'Was BuiltIn',
        source: PresetSource.builtIn,
        signatureHeaders: ['Date'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      final json = builtInPreset.toJson();
      final restored = CsvPreset.fromJson(json);

      expect(restored.source, PresetSource.userSaved);
    });

    test('unknown sourceApp name in JSON falls back to generic', () {
      final json = jsonEncode({
        'id': 'unknown-app',
        'name': 'Unknown App',
        'sourceApp': 'totallyFakeApp',
      });

      final preset = CsvPreset.fromJson(json);
      expect(preset.sourceApp, SourceApp.generic);
    });

    test('unknown expectedUnits name in JSON falls back to metric', () {
      final json = jsonEncode({
        'id': 'unknown-units',
        'name': 'Unknown Units',
        'expectedUnits': 'galactic',
      });

      final preset = CsvPreset.fromJson(json);
      expect(preset.expectedUnits, UnitSystem.metric);
    });

    test('unknown expectedTimeFormat name in JSON falls back to h24', () {
      final json = jsonEncode({
        'id': 'unknown-time',
        'name': 'Unknown Time',
        'expectedTimeFormat': 'sundialTime',
      });

      final preset = CsvPreset.fromJson(json);
      expect(preset.expectedTimeFormat, ExpectedTimeFormat.h24);
    });

    test('unknown supportedEntities name in JSON falls back to dives', () {
      final json = jsonEncode({
        'id': 'unknown-entity',
        'name': 'Unknown Entity',
        'supportedEntities': ['dives', 'unknownEntityType'],
      });

      final preset = CsvPreset.fromJson(json);
      // unknownEntityType should fall back to dives, so set contains only dives
      expect(preset.supportedEntities, contains(ImportEntityType.dives));
    });
  });

  // ======================== isMultiFile getter ========================

  group('isMultiFile', () {
    test('returns false when fileRoles is empty', () {
      const preset = CsvPreset(
        id: 'single-file',
        name: 'Single File',
        signatureHeaders: ['Date'],
        fileRoles: [],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset.isMultiFile, isFalse);
    });

    test('returns false when fileRoles has exactly one role', () {
      const preset = CsvPreset(
        id: 'one-role',
        name: 'One Role',
        signatureHeaders: ['Date'],
        fileRoles: [
          PresetFileRole(
            roleId: 'dive_list',
            label: 'Dive List',
            signatureHeaders: ['dive number'],
          ),
        ],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset.isMultiFile, isFalse);
    });

    test('returns true when fileRoles has two roles', () {
      const preset = CsvPreset(
        id: 'two-roles',
        name: 'Two Roles',
        signatureHeaders: ['Date'],
        fileRoles: [
          PresetFileRole(
            roleId: 'dive_list',
            label: 'Dive List',
            signatureHeaders: ['dive number'],
          ),
          PresetFileRole(
            roleId: 'dive_profile',
            label: 'Dive Profile',
            signatureHeaders: ['sample time (min)'],
          ),
        ],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset.isMultiFile, isTrue);
    });

    test('returns true when fileRoles has more than two roles', () {
      const preset = CsvPreset(
        id: 'three-roles',
        name: 'Three Roles',
        signatureHeaders: ['Date'],
        fileRoles: [
          PresetFileRole(
            roleId: 'dive_list',
            label: 'Dive List',
            signatureHeaders: ['dive number'],
          ),
          PresetFileRole(
            roleId: 'dive_profile',
            label: 'Dive Profile',
            signatureHeaders: ['sample time (min)'],
          ),
          PresetFileRole(
            roleId: 'site_list',
            label: 'Site List',
            signatureHeaders: ['site name'],
          ),
        ],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset.isMultiFile, isTrue);
    });

    test('default fileRoles (empty) means isMultiFile is false', () {
      const preset = CsvPreset(
        id: 'default-roles',
        name: 'Default Roles',
        signatureHeaders: ['Date'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset.isMultiFile, isFalse);
    });
  });

  // ======================== primaryMapping getter ========================

  group('primaryMapping', () {
    test('returns mapping with key "primary"', () {
      const expectedMapping = FieldMapping(
        name: 'Primary Mapping',
        columns: [ColumnMapping(sourceColumn: 'Date', targetField: 'date')],
      );

      const preset = CsvPreset(
        id: 'has-primary',
        name: 'Has Primary',
        signatureHeaders: ['Date'],
        mappings: {'primary': expectedMapping},
      );

      expect(preset.primaryMapping, isNotNull);
      expect(preset.primaryMapping!.name, 'Primary Mapping');
      expect(preset.primaryMapping!.columns.length, 1);
    });

    test('returns null when mappings is empty', () {
      const preset = CsvPreset(
        id: 'empty-mappings',
        name: 'Empty Mappings',
        signatureHeaders: ['Date'],
        mappings: {},
      );

      expect(preset.primaryMapping, isNull);
    });

    test('falls back to "dive_list" when no "primary" key exists', () {
      const preset = CsvPreset(
        id: 'no-primary-key',
        name: 'No Primary Key',
        signatureHeaders: ['Date'],
        mappings: {
          'dive_list': FieldMapping(name: 'Dive List', columns: []),
          'dive_profile': FieldMapping(name: 'Dive Profile', columns: []),
        },
      );

      expect(preset.primaryMapping, isNotNull);
      expect(preset.primaryMapping!.name, 'Dive List');
    });

    test('returns "primary" key even when other keys exist', () {
      const preset = CsvPreset(
        id: 'primary-among-others',
        name: 'Primary Among Others',
        signatureHeaders: ['Date'],
        mappings: {
          'dive_list': FieldMapping(name: 'Dive List', columns: []),
          'primary': FieldMapping(
            name: 'The Primary',
            columns: [ColumnMapping(sourceColumn: 'Date', targetField: 'date')],
          ),
          'dive_profile': FieldMapping(name: 'Dive Profile', columns: []),
        },
      );

      expect(preset.primaryMapping, isNotNull);
      expect(preset.primaryMapping!.name, 'The Primary');
    });
  });

  // ======================== PresetFileRole equality ========================

  group('PresetFileRole equality', () {
    test('two roles with same fields are equal', () {
      const role1 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        required: true,
        signatureHeaders: ['dive number', 'date', 'maxdepth [m]'],
      );
      const role2 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        required: true,
        signatureHeaders: ['dive number', 'date', 'maxdepth [m]'],
      );

      expect(role1, role2);
      expect(role1.hashCode, role2.hashCode);
    });

    test('roles with different roleId are not equal', () {
      const role1 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        signatureHeaders: ['dive number'],
      );
      const role2 = PresetFileRole(
        roleId: 'dive_profile',
        label: 'Dive List',
        signatureHeaders: ['dive number'],
      );

      expect(role1, isNot(role2));
    });

    test('roles with different labels are not equal', () {
      const role1 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        signatureHeaders: ['dive number'],
      );
      const role2 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive Log',
        signatureHeaders: ['dive number'],
      );

      expect(role1, isNot(role2));
    });

    test('roles with different required flag are not equal', () {
      const role1 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        required: true,
        signatureHeaders: ['dive number'],
      );
      const role2 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        required: false,
        signatureHeaders: ['dive number'],
      );

      expect(role1, isNot(role2));
    });

    test('roles with different signatureHeaders are not equal', () {
      const role1 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        signatureHeaders: ['dive number', 'date'],
      );
      const role2 = PresetFileRole(
        roleId: 'dive_list',
        label: 'Dive List',
        signatureHeaders: ['dive number', 'time'],
      );

      expect(role1, isNot(role2));
    });

    test('required defaults to true', () {
      const role = PresetFileRole(
        roleId: 'test',
        label: 'Test',
        signatureHeaders: ['a'],
      );

      expect(role.required, isTrue);
    });

    test('props contains all fields for Equatable', () {
      const role = PresetFileRole(
        roleId: 'test',
        label: 'Test',
        required: false,
        signatureHeaders: ['a', 'b'],
      );

      expect(role.props, hasLength(4));
      expect(role.props[0], 'test');
      expect(role.props[1], 'Test');
      expect(role.props[2], false);
      expect(role.props[3], ['a', 'b']);
    });
  });

  // ======================== CsvPreset equality ========================

  group('CsvPreset equality', () {
    test('two presets with identical fields are equal', () {
      const preset1 = CsvPreset(
        id: 'test',
        name: 'Test',
        source: PresetSource.builtIn,
        sourceApp: SourceApp.subsurface,
        signatureHeaders: ['a'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );
      const preset2 = CsvPreset(
        id: 'test',
        name: 'Test',
        source: PresetSource.builtIn,
        sourceApp: SourceApp.subsurface,
        signatureHeaders: ['a'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      expect(preset1, preset2);
    });

    test('presets with different signatureHeaders are not equal', () {
      const preset1 = CsvPreset(
        id: 'test',
        name: 'Test',
        signatureHeaders: ['a'],
      );
      const preset2 = CsvPreset(
        id: 'test',
        name: 'Test',
        signatureHeaders: ['b'],
      );

      expect(preset1, isNot(preset2));
    });

    test('presets with different ids are not equal', () {
      const preset1 = CsvPreset(id: 'a', name: 'Test');
      const preset2 = CsvPreset(id: 'b', name: 'Test');

      expect(preset1, isNot(preset2));
    });

    test('presets with different names are not equal', () {
      const preset1 = CsvPreset(id: 'test', name: 'Alpha');
      const preset2 = CsvPreset(id: 'test', name: 'Beta');

      expect(preset1, isNot(preset2));
    });
  });

  // ======================== ColumnMapping serialization edge cases ========================

  group('ColumnMapping serialization edge cases', () {
    test('column with no transform or defaultValue roundtrips', () {
      const preset = CsvPreset(
        id: 'col-bare',
        name: 'Col Bare',
        signatureHeaders: ['A'],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary',
            columns: [ColumnMapping(sourceColumn: 'A', targetField: 'fieldA')],
          ),
        },
      );

      final restored = CsvPreset.fromJson(preset.toJson());
      final col = restored.mappings['primary']!.columns.first;

      expect(col.sourceColumn, 'A');
      expect(col.targetField, 'fieldA');
      expect(col.transform, isNull);
      expect(col.defaultValue, isNull);
    });

    test('column with transform but no defaultValue roundtrips', () {
      const preset = CsvPreset(
        id: 'col-transform-only',
        name: 'Col Transform Only',
        signatureHeaders: ['Depth'],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary',
            columns: [
              ColumnMapping(
                sourceColumn: 'Depth',
                targetField: 'maxDepth',
                transform: ValueTransform.feetToMeters,
              ),
            ],
          ),
        },
      );

      final restored = CsvPreset.fromJson(preset.toJson());
      final col = restored.mappings['primary']!.columns.first;

      expect(col.transform, ValueTransform.feetToMeters);
      expect(col.defaultValue, isNull);
    });

    test('column with defaultValue but no transform roundtrips', () {
      const preset = CsvPreset(
        id: 'col-default-only',
        name: 'Col Default Only',
        signatureHeaders: ['Rating'],
        mappings: {
          'primary': FieldMapping(
            name: 'Primary',
            columns: [
              ColumnMapping(
                sourceColumn: 'Rating',
                targetField: 'rating',
                defaultValue: '3',
              ),
            ],
          ),
        },
      );

      final restored = CsvPreset.fromJson(preset.toJson());
      final col = restored.mappings['primary']!.columns.first;

      expect(col.transform, isNull);
      expect(col.defaultValue, '3');
    });

    test('all ValueTransform values roundtrip through JSON', () {
      for (final transform in ValueTransform.values) {
        final preset = CsvPreset(
          id: 'transform-${transform.name}',
          name: 'Transform ${transform.name}',
          signatureHeaders: ['Col'],
          mappings: {
            'primary': FieldMapping(
              name: 'Primary',
              columns: [
                ColumnMapping(
                  sourceColumn: 'Col',
                  targetField: 'field',
                  transform: transform,
                ),
              ],
            ),
          },
        );

        final restored = CsvPreset.fromJson(preset.toJson());
        final col = restored.mappings['primary']!.columns.first;

        expect(
          col.transform,
          transform,
          reason: 'Failed roundtrip for ValueTransform.${transform.name}',
        );
      }
    });
  });
}
