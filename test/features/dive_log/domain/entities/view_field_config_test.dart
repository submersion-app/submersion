import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

void main() {
  group('TableColumnConfig', () {
    test('creates with defaults', () {
      final config = TableColumnConfig(field: DiveField.maxDepth);
      expect(config.width, equals(DiveField.maxDepth.defaultWidth));
      expect(config.isPinned, isFalse);
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
  });
}
