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
      container.dispose();
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
  });
}
