import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';

void main() {
  group('TableViewConfigNotifier', () {
    late TableViewConfigNotifier notifier;

    setUp(() {
      notifier = TableViewConfigNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('starts with default config', () {
      final config = notifier.state;
      expect(config.columns.length, greaterThanOrEqualTo(5));
      expect(config.columns.first.field, equals(DiveField.diveNumber));
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });

    test('toggleColumn adds a new column', () {
      final before = notifier.state.columns.length;
      notifier.toggleColumn(DiveField.buddy);
      expect(notifier.state.columns.length, equals(before + 1));
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.buddy),
        isTrue,
      );
    });

    test('toggleColumn removes an existing non-pinned column', () {
      // waterTemp is in the default config and is not pinned
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.waterTemp),
        isTrue,
      );
      final before = notifier.state.columns.length;
      notifier.toggleColumn(DiveField.waterTemp);
      expect(notifier.state.columns.length, equals(before - 1));
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.waterTemp),
        isFalse,
      );
    });

    test('toggleColumn does not remove a pinned column', () {
      // diveNumber is pinned in the default config
      expect(
        notifier.state.columns.any(
          (c) => c.field == DiveField.diveNumber && c.isPinned,
        ),
        isTrue,
      );
      final before = notifier.state.columns.length;
      notifier.toggleColumn(DiveField.diveNumber);
      // column count should not change
      expect(notifier.state.columns.length, equals(before));
    });

    test(
      'setSortField updates sort state: unsorted -> asc -> desc -> unsorted',
      () {
        // initial: no sort
        expect(notifier.state.sortField, isNull);

        // first set: ascending
        notifier.setSortField(DiveField.maxDepth);
        expect(notifier.state.sortField, equals(DiveField.maxDepth));
        expect(notifier.state.sortAscending, isTrue);

        // second set (same field): descending
        notifier.setSortField(DiveField.maxDepth);
        expect(notifier.state.sortField, equals(DiveField.maxDepth));
        expect(notifier.state.sortAscending, isFalse);

        // third set (same field): clears sort
        notifier.setSortField(DiveField.maxDepth);
        expect(notifier.state.sortField, isNull);
      },
    );

    test('resizeColumn updates width', () {
      notifier.resizeColumn(DiveField.siteName, 250);
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.siteName,
      );
      expect(col.width, equals(250));
    });

    test('resizeColumn enforces minWidth', () {
      notifier.resizeColumn(DiveField.siteName, 10);
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.siteName,
      );
      expect(col.width, greaterThanOrEqualTo(DiveField.siteName.minWidth));
    });

    test('reorderColumn moves column to new position', () {
      final cols = notifier.state.columns;
      final lastField = cols.last.field;
      notifier.reorderColumn(cols.length - 1, 2);
      expect(notifier.state.columns[2].field, equals(lastField));
    });

    test('togglePin pins and unpins a column', () {
      // dateTime is not pinned in default config
      expect(
        notifier.state.columns
            .firstWhere((c) => c.field == DiveField.dateTime)
            .isPinned,
        isFalse,
      );

      notifier.togglePin(DiveField.dateTime);
      expect(
        notifier.state.columns
            .firstWhere((c) => c.field == DiveField.dateTime)
            .isPinned,
        isTrue,
      );

      notifier.togglePin(DiveField.dateTime);
      expect(
        notifier.state.columns
            .firstWhere((c) => c.field == DiveField.dateTime)
            .isPinned,
        isFalse,
      );
    });

    test('applyPreset replaces config with Technical preset', () {
      final presets = FieldPreset.builtInTablePresets();
      final technical = presets.firstWhere((p) => p.name == 'Technical');

      notifier.applyPreset(technical);

      final config = notifier.state;
      // Technical preset includes gradientFactorLow as a GF field
      expect(
        config.columns.any((c) => c.field == DiveField.gradientFactorLow) ||
            config.columns.any((c) => c.field == DiveField.sacRate),
        isTrue,
      );
    });
  });

  group('CardViewConfigNotifier', () {
    late CardViewConfigNotifier notifier;

    setUp(() {
      notifier = CardViewConfigNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('starts with default compact config when mode not set', () {
      final config = notifier.state;
      expect(config.slots, isNotEmpty);
    });

    test('updateSlot changes the field for a named slot', () {
      // Start with compact mode default (title slot = siteName)
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.updateSlot('title', DiveField.tripName);
      final slot = notifier.state.slots.firstWhere((s) => s.slotId == 'title');
      expect(slot.field, equals(DiveField.tripName));
    });

    test('setExtraFields replaces extra fields list', () {
      notifier.setExtraFields([DiveField.buddy, DiveField.waterTemp]);
      expect(
        notifier.state.extraFields,
        equals([DiveField.buddy, DiveField.waterTemp]),
      );
    });

    test('addExtraField appends if not present', () {
      notifier.setExtraFields([DiveField.buddy]);
      notifier.addExtraField(DiveField.waterTemp);
      expect(notifier.state.extraFields, contains(DiveField.waterTemp));
      expect(notifier.state.extraFields.length, equals(2));
    });

    test('addExtraField does not duplicate', () {
      notifier.setExtraFields([DiveField.buddy]);
      notifier.addExtraField(DiveField.buddy);
      expect(notifier.state.extraFields.length, equals(1));
    });

    test('removeExtraField filters out the field', () {
      notifier.setExtraFields([DiveField.buddy, DiveField.waterTemp]);
      notifier.removeExtraField(DiveField.buddy);
      expect(notifier.state.extraFields, isNot(contains(DiveField.buddy)));
      expect(notifier.state.extraFields.length, equals(1));
    });

    test('reorderExtraFields moves field to new position', () {
      notifier.setExtraFields([
        DiveField.buddy,
        DiveField.waterTemp,
        DiveField.airTemp,
      ]);
      notifier.reorderExtraFields(2, 0);
      expect(notifier.state.extraFields.first, equals(DiveField.airTemp));
    });

    test('resetToDefault restores default config', () {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.setExtraFields([DiveField.buddy]);
      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
    });
  });
}
