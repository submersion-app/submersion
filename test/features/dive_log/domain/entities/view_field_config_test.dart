import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

void main() {
  group('TableColumnConfig', () {
    test('creates with defaults', () {
      final config = TableColumnConfig(field: DiveField.maxDepth);
      expect(config.width, equals(DiveField.maxDepth.defaultWidth));
      expect(config.isPinned, isFalse);
    });

    test('creates with explicit width', () {
      final config = TableColumnConfig(field: DiveField.maxDepth, width: 200);
      expect(config.width, equals(200));
    });

    test('serializes to and from JSON', () {
      final config = TableColumnConfig(
        field: DiveField.siteName,
        width: 200,
        isPinned: true,
      );
      final json = config.toJson();
      final restored = TableColumnConfig.fromJson(json);
      expect(restored.field, equals(DiveField.siteName));
      expect(restored.width, equals(200));
      expect(restored.isPinned, isTrue);
    });

    test('fromJson falls back to diveNumber for unknown field name', () {
      final json = {'field': 'unknownField', 'width': 100.0, 'isPinned': false};
      final restored = TableColumnConfig.fromJson(json);
      expect(restored.field, equals(DiveField.diveNumber));
    });

    test('copyWith returns new instance with changed fields', () {
      final original = TableColumnConfig(
        field: DiveField.maxDepth,
        width: 100,
        isPinned: false,
      );
      final modified = original.copyWith(
        field: DiveField.siteName,
        width: 200,
        isPinned: true,
      );
      expect(modified.field, equals(DiveField.siteName));
      expect(modified.width, equals(200));
      expect(modified.isPinned, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final original = TableColumnConfig(
        field: DiveField.maxDepth,
        width: 150,
        isPinned: true,
      );
      final modified = original.copyWith();
      expect(modified.field, equals(DiveField.maxDepth));
      expect(modified.width, equals(150));
      expect(modified.isPinned, isTrue);
    });

    test('props returns all fields for equality', () {
      final config = TableColumnConfig(
        field: DiveField.maxDepth,
        width: 100,
        isPinned: false,
      );
      expect(config.props, equals([DiveField.maxDepth, 100.0, false]));
    });
  });

  group('TableViewConfig', () {
    test('defaultConfig has expected columns', () {
      final config = TableViewConfig.defaultConfig();
      expect(config.columns.length, greaterThanOrEqualTo(5));
      expect(config.columns.first.field, equals(DiveField.diveNumber));
      expect(config.columns.first.isPinned, isTrue);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });

    test('serializes round-trip', () {
      final config = TableViewConfig.defaultConfig().copyWith(
        sortField: DiveField.dateTime,
        sortAscending: false,
      );
      final json = jsonEncode(config.toJson());
      final restored = TableViewConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(restored.columns.length, equals(config.columns.length));
      expect(restored.sortField, equals(DiveField.dateTime));
      expect(restored.sortAscending, isFalse);
    });

    test('fromJson with null sortField', () {
      final json = {
        'columns': [
          {'field': 'maxDepth', 'width': 100.0, 'isPinned': false},
        ],
        'sortField': null,
        'sortAscending': true,
      };
      final config = TableViewConfig.fromJson(json);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });

    test('fromJson defaults sortAscending to true when missing', () {
      final json = {
        'columns': [
          {'field': 'maxDepth', 'width': 100.0, 'isPinned': false},
        ],
        'sortField': 'maxDepth',
      };
      final config = TableViewConfig.fromJson(json);
      expect(config.sortAscending, isTrue);
    });

    test('fromJson handles unknown sortField name gracefully', () {
      final json = {
        'columns': [
          {'field': 'maxDepth', 'width': 100.0, 'isPinned': false},
        ],
        'sortField': 'nonexistentField',
        'sortAscending': true,
      };
      final config = TableViewConfig.fromJson(json);
      // Unknown field name should result in null sortField
      expect(config.sortField, isNull);
    });

    test('copyWith clearSortField clears the sort field', () {
      final config = TableViewConfig.defaultConfig().copyWith(
        sortField: DiveField.maxDepth,
      );
      expect(config.sortField, equals(DiveField.maxDepth));

      final cleared = config.copyWith(clearSortField: true);
      expect(cleared.sortField, isNull);
    });

    test('props includes all fields', () {
      final config = TableViewConfig(
        columns: [TableColumnConfig(field: DiveField.maxDepth)],
        sortField: DiveField.dateTime,
        sortAscending: false,
      );
      expect(config.props.length, equals(3));
      expect(config.props[1], equals(DiveField.dateTime));
      expect(config.props[2], equals(false));
    });
  });

  group('CardSlotConfig', () {
    test('creates with required fields', () {
      const slot = CardSlotConfig(slotId: 'title', field: DiveField.siteName);
      expect(slot.slotId, equals('title'));
      expect(slot.field, equals(DiveField.siteName));
    });

    test('copyWith changes specific fields', () {
      const original = CardSlotConfig(
        slotId: 'title',
        field: DiveField.siteName,
      );
      final modified = original.copyWith(field: DiveField.tripName);
      expect(modified.slotId, equals('title'));
      expect(modified.field, equals(DiveField.tripName));
    });

    test('copyWith with slotId', () {
      const original = CardSlotConfig(
        slotId: 'title',
        field: DiveField.siteName,
      );
      final modified = original.copyWith(slotId: 'date');
      expect(modified.slotId, equals('date'));
      expect(modified.field, equals(DiveField.siteName));
    });

    test('toJson serializes correctly', () {
      const slot = CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth);
      final json = slot.toJson();
      expect(json['slotId'], equals('stat1'));
      expect(json['field'], equals('maxDepth'));
    });

    test('fromJson deserializes correctly', () {
      final json = {'slotId': 'stat1', 'field': 'maxDepth'};
      final slot = CardSlotConfig.fromJson(json);
      expect(slot.slotId, equals('stat1'));
      expect(slot.field, equals(DiveField.maxDepth));
    });

    test('fromJson falls back to diveNumber for unknown field', () {
      final json = {'slotId': 'stat1', 'field': 'unknownField'};
      final slot = CardSlotConfig.fromJson(json);
      expect(slot.field, equals(DiveField.diveNumber));
    });

    test('props returns slotId and field', () {
      const slot = CardSlotConfig(slotId: 'title', field: DiveField.siteName);
      expect(slot.props, equals(['title', DiveField.siteName]));
    });
  });

  group('CardViewConfig', () {
    test('defaultCompactConfig has 4 slots', () {
      final config = CardViewConfig.defaultCompact();
      expect(config.slots.length, equals(4));
      expect(config.slots[0].slotId, equals('title'));
      expect(config.slots[0].field, equals(DiveField.siteName));
    });

    test('defaultDenseConfig has 4 slots', () {
      final config = CardViewConfig.defaultDense();
      expect(config.slots.length, equals(4));
    });

    test('defaultDetailedConfig has empty extraFields', () {
      final config = CardViewConfig.defaultDetailed();
      expect(config.extraFields, isEmpty);
    });

    test('serializes round-trip', () {
      final config = CardViewConfig.defaultCompact();
      final json = jsonEncode(config.toJson());
      final restored = CardViewConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(restored.slots.length, equals(config.slots.length));
      expect(restored.mode, equals(config.mode));
    });

    test('serializes round-trip with extraFields', () {
      final config = CardViewConfig.defaultCompact().copyWith(
        extraFields: [DiveField.buddy, DiveField.waterTemp],
      );
      final json = jsonEncode(config.toJson());
      final restored = CardViewConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(restored.extraFields.length, equals(2));
      expect(restored.extraFields.first, equals(DiveField.buddy));
    });

    test('fromJson handles null extraFields', () {
      final json = {
        'mode': 'compact',
        'slots': [
          {'slotId': 'title', 'field': 'siteName'},
        ],
      };
      final config = CardViewConfig.fromJson(json);
      expect(config.extraFields, isEmpty);
    });

    test('fromJson filters out unknown extra field names', () {
      final json = {
        'mode': 'compact',
        'slots': [
          {'slotId': 'title', 'field': 'siteName'},
        ],
        'extraFields': ['buddy', 'nonexistentField', 'waterTemp'],
      };
      final config = CardViewConfig.fromJson(json);
      expect(config.extraFields.length, equals(2));
      expect(config.extraFields, contains(DiveField.buddy));
      expect(config.extraFields, contains(DiveField.waterTemp));
    });

    test('copyWith changes specific fields', () {
      final original = CardViewConfig.defaultCompact();
      final modified = original.copyWith(
        mode: ListViewMode.dense,
        extraFields: [DiveField.buddy],
      );
      expect(modified.mode, equals(ListViewMode.dense));
      expect(modified.extraFields, equals([DiveField.buddy]));
      // slots unchanged
      expect(modified.slots.length, equals(original.slots.length));
    });

    test('copyWith preserves unchanged fields', () {
      final original = CardViewConfig.defaultCompact();
      final modified = original.copyWith();
      expect(modified.mode, equals(original.mode));
      expect(modified.slots.length, equals(original.slots.length));
      expect(modified.extraFields, equals(original.extraFields));
    });

    test('props includes mode, slots, and extraFields', () {
      final config = CardViewConfig.defaultCompact();
      expect(config.props.length, equals(3));
    });
  });

  group('FieldPreset', () {
    test('built-in presets exist', () {
      final presets = FieldPreset.builtInTablePresets();
      expect(presets.length, equals(3));
      expect(
        presets.map((p) => p.name),
        containsAll(['Standard', 'Technical', 'Planning']),
      );
      expect(presets.every((p) => p.isBuiltIn), isTrue);
    });

    test('built-in presets have table viewMode', () {
      final presets = FieldPreset.builtInTablePresets();
      expect(presets.every((p) => p.viewMode == ListViewMode.table), isTrue);
    });

    test('built-in presets have valid configJson', () {
      final presets = FieldPreset.builtInTablePresets();
      for (final preset in presets) {
        final config = TableViewConfig.fromJson(preset.configJson);
        expect(config.columns, isNotEmpty);
      }
    });

    test('copyWith changes specific fields', () {
      final preset = FieldPreset.builtInTablePresets().first;
      final modified = preset.copyWith(name: 'Custom', isBuiltIn: false);
      expect(modified.name, equals('Custom'));
      expect(modified.isBuiltIn, isFalse);
      expect(modified.id, equals(preset.id));
      expect(modified.viewMode, equals(preset.viewMode));
      expect(modified.configJson, equals(preset.configJson));
    });

    test('copyWith preserves all fields when no changes', () {
      final preset = FieldPreset.builtInTablePresets().first;
      final copy = preset.copyWith();
      expect(copy.id, equals(preset.id));
      expect(copy.name, equals(preset.name));
      expect(copy.viewMode, equals(preset.viewMode));
      expect(copy.isBuiltIn, equals(preset.isBuiltIn));
    });

    test('copyWith can change id and viewMode', () {
      final preset = FieldPreset.builtInTablePresets().first;
      final modified = preset.copyWith(
        id: 'new-id',
        viewMode: ListViewMode.compact,
        configJson: {'custom': true},
      );
      expect(modified.id, equals('new-id'));
      expect(modified.viewMode, equals(ListViewMode.compact));
      expect(modified.configJson, equals({'custom': true}));
    });

    test('props includes all fields for equality', () {
      final preset = FieldPreset.builtInTablePresets().first;
      expect(preset.props.length, equals(5));
    });

    test('equality works with same data', () {
      final presets1 = FieldPreset.builtInTablePresets();
      final presets2 = FieldPreset.builtInTablePresets();
      expect(presets1.first, equals(presets2.first));
    });

    test('constructor with isBuiltIn default false', () {
      const preset = FieldPreset(
        id: 'user-1',
        name: 'My preset',
        viewMode: ListViewMode.table,
        configJson: {},
      );
      expect(preset.isBuiltIn, isFalse);
    });
  });
}
