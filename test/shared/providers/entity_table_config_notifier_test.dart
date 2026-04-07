import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

enum TestField implements EntityField {
  fieldA,
  fieldB,
  fieldC;

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

EntityTableViewConfig<TestField> _defaultConfig() {
  return EntityTableViewConfig<TestField>(
    columns: [
      EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        isPinned: true,
      ),
      EntityTableColumnConfig<TestField>(field: TestField.fieldB),
    ],
  );
}

EntityTableConfigNotifier<TestField> _makeNotifier() {
  return EntityTableConfigNotifier<TestField>(
    defaultConfig: _defaultConfig(),
    fieldFromName: (name) => TestField.values.firstWhere((e) => e.name == name),
  );
}

void main() {
  group('EntityTableConfigNotifier', () {
    late ProviderContainer container;
    late EntityTableConfigNotifier<TestField> notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = _makeNotifier();
    });

    tearDown(() {
      notifier.dispose();
      container.dispose();
    });

    // ------------------------------------------------------------------
    // default state
    // ------------------------------------------------------------------

    test('starts with default config', () {
      expect(notifier.state.columns.length, equals(2));
      expect(notifier.state.columns.first.field, equals(TestField.fieldA));
      expect(notifier.state.sortField, isNull);
      expect(notifier.state.sortAscending, isTrue);
    });

    // ------------------------------------------------------------------
    // toggleColumn
    // ------------------------------------------------------------------

    group('toggleColumn', () {
      test('adds a field that is not present', () {
        notifier.toggleColumn(TestField.fieldC);

        expect(
          notifier.state.columns.map((c) => c.field),
          containsAll([TestField.fieldA, TestField.fieldB, TestField.fieldC]),
        );
      });

      test('removes a field that is present and not pinned', () {
        notifier.toggleColumn(TestField.fieldB);

        expect(
          notifier.state.columns.map((c) => c.field),
          isNot(contains(TestField.fieldB)),
        );
      });

      test('does not remove a pinned column', () {
        // fieldA is pinned in the default config
        notifier.toggleColumn(TestField.fieldA);

        expect(
          notifier.state.columns.map((c) => c.field),
          contains(TestField.fieldA),
        );
      });
    });

    // ------------------------------------------------------------------
    // setSortField
    // ------------------------------------------------------------------

    group('setSortField', () {
      test('first call sets field with ascending order', () {
        notifier.setSortField(TestField.fieldA);

        expect(notifier.state.sortField, equals(TestField.fieldA));
        expect(notifier.state.sortAscending, isTrue);
      });

      test('second call on same field switches to descending', () {
        notifier.setSortField(TestField.fieldA);
        notifier.setSortField(TestField.fieldA);

        expect(notifier.state.sortField, equals(TestField.fieldA));
        expect(notifier.state.sortAscending, isFalse);
      });

      test('third call on same field clears sort', () {
        notifier.setSortField(TestField.fieldA);
        notifier.setSortField(TestField.fieldA);
        notifier.setSortField(TestField.fieldA);

        expect(notifier.state.sortField, isNull);
        expect(notifier.state.sortAscending, isTrue);
      });

      test('switching to a different field resets to ascending', () {
        notifier.setSortField(TestField.fieldA);
        notifier.setSortField(TestField.fieldA); // descending
        notifier.setSortField(TestField.fieldB); // new field -> ascending

        expect(notifier.state.sortField, equals(TestField.fieldB));
        expect(notifier.state.sortAscending, isTrue);
      });
    });

    // ------------------------------------------------------------------
    // resizeColumn
    // ------------------------------------------------------------------

    group('resizeColumn', () {
      test('updates column width to the given value', () {
        notifier.resizeColumn(TestField.fieldB, 200.0);

        final col = notifier.state.columns.firstWhere(
          (c) => c.field == TestField.fieldB,
        );
        expect(col.width, equals(200.0));
      });

      test('clamps width to minWidth', () {
        notifier.resizeColumn(TestField.fieldB, 1.0); // below minWidth of 50

        final col = notifier.state.columns.firstWhere(
          (c) => c.field == TestField.fieldB,
        );
        expect(col.width, equals(TestField.fieldB.minWidth));
      });

      test('clamps width to 600 max', () {
        notifier.resizeColumn(TestField.fieldB, 9999.0);

        final col = notifier.state.columns.firstWhere(
          (c) => c.field == TestField.fieldB,
        );
        expect(col.width, equals(600.0));
      });
    });

    // ------------------------------------------------------------------
    // reorderColumn
    // ------------------------------------------------------------------

    group('reorderColumn', () {
      test('moves column from old index to new index', () {
        // Initial: [fieldA, fieldB]. Move fieldA (0) to position 2 (after fieldB).
        notifier.reorderColumn(0, 2);

        expect(notifier.state.columns[0].field, equals(TestField.fieldB));
        expect(notifier.state.columns[1].field, equals(TestField.fieldA));
      });

      test('moving column to same position leaves order unchanged', () {
        // Moving index 0 to index 1 (adjacent) should keep fieldA first.
        notifier.reorderColumn(0, 1);

        expect(notifier.state.columns[0].field, equals(TestField.fieldA));
        expect(notifier.state.columns[1].field, equals(TestField.fieldB));
      });
    });

    // ------------------------------------------------------------------
    // togglePin
    // ------------------------------------------------------------------

    group('togglePin', () {
      test('pins an unpinned column', () {
        notifier.togglePin(TestField.fieldB);

        final col = notifier.state.columns.firstWhere(
          (c) => c.field == TestField.fieldB,
        );
        expect(col.isPinned, isTrue);
      });

      test('unpins a pinned column', () {
        // fieldA starts pinned
        notifier.togglePin(TestField.fieldA);

        final col = notifier.state.columns.firstWhere(
          (c) => c.field == TestField.fieldA,
        );
        expect(col.isPinned, isFalse);
      });
    });

    // ------------------------------------------------------------------
    // dispose
    // ------------------------------------------------------------------

    test('dispose cancels pending save timer', () {
      // Trigger a mutation to start the save timer
      notifier.toggleColumn(TestField.fieldC);
      // Dispose should not throw
      notifier.dispose();
      // Recreate for tearDown
      notifier = _makeNotifier();
    });

    test('multiple rapid mutations each trigger save path without error', () {
      notifier.toggleColumn(TestField.fieldC);
      notifier.setSortField(TestField.fieldA);
      notifier.resizeColumn(TestField.fieldB, 180);
      notifier.togglePin(TestField.fieldB);
      notifier.reorderColumn(0, 2);
      // All mutations should have completed without throwing
      expect(notifier.state.columns.length, greaterThanOrEqualTo(2));
      notifier.dispose();
      notifier = _makeNotifier();
    });

    test('toggle then re-toggle column round-trips correctly', () {
      // Add fieldC
      notifier.toggleColumn(TestField.fieldC);
      expect(
        notifier.state.columns.map((c) => c.field),
        contains(TestField.fieldC),
      );
      // Remove fieldC
      notifier.toggleColumn(TestField.fieldC);
      expect(
        notifier.state.columns.map((c) => c.field),
        isNot(contains(TestField.fieldC)),
      );
      // Add it back
      notifier.toggleColumn(TestField.fieldC);
      expect(
        notifier.state.columns.map((c) => c.field),
        contains(TestField.fieldC),
      );
    });
  });

  // --------------------------------------------------------------------
  // EntityTableViewConfig serialization
  // --------------------------------------------------------------------

  group('EntityTableViewConfig', () {
    test('toJson and fromJson round-trip', () {
      final config = EntityTableViewConfig<TestField>(
        columns: [
          EntityTableColumnConfig<TestField>(
            field: TestField.fieldA,
            isPinned: true,
            width: 120,
          ),
          EntityTableColumnConfig<TestField>(
            field: TestField.fieldB,
            width: 200,
          ),
        ],
        sortField: TestField.fieldA,
        sortAscending: false,
      );

      final json = config.toJson();
      final restored = EntityTableViewConfig.fromJson<TestField>(
        json,
        (name) => TestField.values.firstWhere((e) => e.name == name),
      );

      expect(restored.columns.length, equals(2));
      expect(restored.columns.first.field, equals(TestField.fieldA));
      expect(restored.columns.first.isPinned, isTrue);
      expect(restored.columns.first.width, equals(120));
      expect(restored.sortField, equals(TestField.fieldA));
      expect(restored.sortAscending, isFalse);
    });

    test('fromJson with null sortField', () {
      final json = {
        'columns': [
          {'field': 'fieldA', 'width': 100.0, 'isPinned': false},
        ],
        'sortField': null,
        'sortAscending': true,
      };
      final config = EntityTableViewConfig.fromJson<TestField>(
        json,
        (name) => TestField.values.firstWhere((e) => e.name == name),
      );
      expect(config.sortField, isNull);
    });

    test('fromJson defaults sortAscending when missing', () {
      final json = {
        'columns': [
          {'field': 'fieldA', 'width': 100.0, 'isPinned': false},
        ],
      };
      final config = EntityTableViewConfig.fromJson<TestField>(
        json,
        (name) => TestField.values.firstWhere((e) => e.name == name),
      );
      expect(config.sortAscending, isTrue);
    });

    test('copyWith clearSortField', () {
      final config = EntityTableViewConfig<TestField>(
        columns: [EntityTableColumnConfig<TestField>(field: TestField.fieldA)],
        sortField: TestField.fieldA,
      );
      final cleared = config.copyWith(clearSortField: true);
      expect(cleared.sortField, isNull);
    });

    test('props includes all fields', () {
      final config = EntityTableViewConfig<TestField>(
        columns: [EntityTableColumnConfig<TestField>(field: TestField.fieldA)],
        sortField: TestField.fieldA,
        sortAscending: false,
      );
      expect(config.props.length, equals(3));
    });

    test('toJson serializes to valid JSON string', () {
      final config = EntityTableViewConfig<TestField>(
        columns: [EntityTableColumnConfig<TestField>(field: TestField.fieldA)],
        sortField: TestField.fieldB,
        sortAscending: false,
      );
      final jsonStr = jsonEncode(config.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['sortField'], equals('fieldB'));
      expect(decoded['sortAscending'], equals(false));
    });
  });

  // --------------------------------------------------------------------
  // EntityTableColumnConfig serialization
  // --------------------------------------------------------------------

  group('EntityTableColumnConfig', () {
    test('fromJson deserializes correctly', () {
      final json = {'field': 'fieldB', 'width': 150.0, 'isPinned': true};
      final config = EntityTableColumnConfig.fromJson<TestField>(
        json,
        (name) => TestField.values.firstWhere((e) => e.name == name),
      );
      expect(config.field, equals(TestField.fieldB));
      expect(config.width, equals(150.0));
      expect(config.isPinned, isTrue);
    });

    test('toJson serializes correctly', () {
      final config = EntityTableColumnConfig<TestField>(
        field: TestField.fieldC,
        width: 175,
        isPinned: true,
      );
      final json = config.toJson();
      expect(json['field'], equals('fieldC'));
      expect(json['width'], equals(175.0));
      expect(json['isPinned'], isTrue);
    });

    test('copyWith changes specific fields', () {
      final original = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 100,
        isPinned: false,
      );
      final modified = original.copyWith(width: 200, isPinned: true);
      expect(modified.field, equals(TestField.fieldA));
      expect(modified.width, equals(200));
      expect(modified.isPinned, isTrue);
    });

    test('default width comes from field', () {
      final config = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
      );
      expect(config.width, equals(TestField.fieldA.defaultWidth));
    });

    test('props returns all fields', () {
      final config = EntityTableColumnConfig<TestField>(
        field: TestField.fieldA,
        width: 100,
        isPinned: true,
      );
      expect(config.props, equals([TestField.fieldA, 100.0, true]));
    });
  });
}
