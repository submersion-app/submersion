import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

/// Minimal [EntityField] enum used throughout these tests. It avoids pulling
/// in any application-specific field definitions.
enum TestField implements EntityField {
  fieldA,
  fieldB;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => name;

  @override
  String get shortLabel => name;

  @override
  IconData? get icon => null;

  @override
  double get defaultWidth => 100;

  @override
  double get minWidth => 50;

  @override
  bool get sortable => true;

  @override
  String get categoryName => 'test';

  @override
  bool get isRightAligned => false;
}

TestField _fieldFromName(String name) {
  return TestField.values.firstWhere((e) => e.name == name);
}

void main() {
  group('EntityTableColumnConfig', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final config = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 120.0,
        isPinned: true,
      );

      final json = config.toJson();
      final restored = EntityTableColumnConfig.fromJson<TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.field, equals(TestField.fieldA));
      expect(restored.width, equals(120.0));
      expect(restored.isPinned, isTrue);
    });

    test('uses defaultWidth when width is not supplied', () {
      final config = EntityTableColumnConfig<TestField>(
        field: TestField.fieldB,
      );

      expect(config.width, equals(TestField.fieldB.defaultWidth));
    });

    test('copyWith replaces only the supplied fields', () {
      final original = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 80.0,
        isPinned: false,
      );

      final updated = original.copyWith(width: 200.0, isPinned: true);

      expect(updated.field, equals(TestField.fieldA));
      expect(updated.width, equals(200.0));
      expect(updated.isPinned, isTrue);
    });

    test('props equality works correctly', () {
      final a = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 100.0,
        isPinned: false,
      );
      final b = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 100.0,
        isPinned: false,
      );

      expect(a, equals(b));
    });
  });

  group('EntityTableViewConfig', () {
    EntityTableViewConfig<TestField> makeConfig({
      TestField? sortField,
      bool sortAscending = true,
    }) {
      return EntityTableViewConfig<TestField>(
        columns: [
          EntityTableColumnConfig<TestField>(field: TestField.fieldA),
          EntityTableColumnConfig<TestField>(field: TestField.fieldB),
        ],
        sortField: sortField,
        sortAscending: sortAscending,
      );
    }

    test('toJson / fromJson roundtrip with no sort field', () {
      final config = makeConfig();

      final json = config.toJson();
      final restored = EntityTableViewConfig.fromJson<TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.columns.length, equals(2));
      expect(restored.columns[0].field, equals(TestField.fieldA));
      expect(restored.columns[1].field, equals(TestField.fieldB));
      expect(restored.sortField, isNull);
      expect(restored.sortAscending, isTrue);
    });

    test('toJson / fromJson roundtrip with sort field and descending', () {
      final config = makeConfig(
        sortField: TestField.fieldB,
        sortAscending: false,
      );

      final json = config.toJson();
      final restored = EntityTableViewConfig.fromJson<TestField>(
        json,
        _fieldFromName,
      );

      expect(restored.sortField, equals(TestField.fieldB));
      expect(restored.sortAscending, isFalse);
    });

    test('copyWith replaces columns', () {
      final config = makeConfig();
      final updated = config.copyWith(
        columns: [EntityTableColumnConfig<TestField>(field: TestField.fieldA)],
      );

      expect(updated.columns.length, equals(1));
      expect(updated.sortField, isNull);
    });

    test('copyWith replaces sortField', () {
      final config = makeConfig();
      final updated = config.copyWith(sortField: TestField.fieldA);

      expect(updated.sortField, equals(TestField.fieldA));
    });

    test('copyWith with clearSortField sets sortField to null', () {
      final config = makeConfig(sortField: TestField.fieldA);
      final updated = config.copyWith(
        clearSortField: true,
        sortAscending: true,
      );

      expect(updated.sortField, isNull);
      expect(updated.sortAscending, isTrue);
    });

    test('clearSortField takes precedence over sortField argument', () {
      final config = makeConfig(sortField: TestField.fieldA);
      final updated = config.copyWith(
        sortField: TestField.fieldB,
        clearSortField: true,
      );

      expect(updated.sortField, isNull);
    });

    test('fromJson with null sortAscending defaults to true', () {
      final json = {
        'columns': [
          {'field': 'fieldA', 'width': 100.0, 'isPinned': false},
        ],
        'sortField': null,
        // sortAscending intentionally omitted
      };

      final config = EntityTableViewConfig.fromJson<TestField>(
        json,
        _fieldFromName,
      );

      expect(config.sortAscending, isTrue);
    });
  });
}
