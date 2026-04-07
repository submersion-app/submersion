import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';

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

    test('setSortField switching to different field resets ascending', () {
      notifier.setSortField(DiveField.maxDepth);
      notifier.setSortField(DiveField.maxDepth); // descending
      notifier.setSortField(DiveField.bottomTime); // new field -> ascending
      expect(notifier.state.sortField, equals(DiveField.bottomTime));
      expect(notifier.state.sortAscending, isTrue);
    });

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

    test('resizeColumn enforces max width of 600', () {
      notifier.resizeColumn(DiveField.siteName, 9999.0);
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.siteName,
      );
      expect(col.width, equals(600.0));
    });

    test('reorderColumn moves column to new position', () {
      final cols = notifier.state.columns;
      final lastField = cols.last.field;
      notifier.reorderColumn(cols.length - 1, 2);
      expect(notifier.state.columns[2].field, equals(lastField));
    });

    test('reorderColumn handles moving to same position', () {
      final before = notifier.state.columns.map((c) => c.field).toList();
      notifier.reorderColumn(0, 1);
      final after = notifier.state.columns.map((c) => c.field).toList();
      expect(after, equals(before));
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

    test('applyPreset replaces config with Planning preset', () {
      final presets = FieldPreset.builtInTablePresets();
      final planning = presets.firstWhere((p) => p.name == 'Planning');

      notifier.applyPreset(planning);

      final config = notifier.state;
      expect(config.columns.any((c) => c.field == DiveField.buddy), isTrue);
      expect(config.columns.any((c) => c.field == DiveField.notes), isTrue);
    });

    test('replaceConfig replaces config directly', () {
      final newConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.maxDepth, isPinned: true),
          TableColumnConfig(field: DiveField.avgDepth),
        ],
      );

      notifier.replaceConfig(newConfig);

      expect(notifier.state.columns.length, equals(2));
      expect(notifier.state.columns.first.field, equals(DiveField.maxDepth));
      expect(notifier.state.columns.first.isPinned, isTrue);
    });

    test('replaceConfig with sort state', () {
      final newConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        ],
        sortField: DiveField.dateTime,
        sortAscending: false,
      );

      notifier.replaceConfig(newConfig);

      expect(notifier.state.sortField, equals(DiveField.dateTime));
      expect(notifier.state.sortAscending, isFalse);
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

    test('withMode constructor uses dense defaults', () {
      final dense = CardViewConfigNotifier.withMode(ListViewMode.dense);
      addTearDown(dense.dispose);
      expect(dense.state.mode, equals(ListViewMode.dense));
      expect(dense.state.slots.first.slotId, equals('slot1'));
    });

    test('withMode constructor uses detailed defaults', () {
      final detailed = CardViewConfigNotifier.withMode(ListViewMode.detailed);
      addTearDown(detailed.dispose);
      expect(detailed.state.mode, equals(ListViewMode.detailed));
    });

    test('withMode constructor uses detailed defaults for table mode', () {
      final table = CardViewConfigNotifier.withMode(ListViewMode.table);
      addTearDown(table.dispose);
      // table mode falls through to detailed defaults
      expect(table.state.mode, equals(ListViewMode.detailed));
    });

    test('updateSlot changes the field for a named slot', () {
      // Start with compact mode default (title slot = siteName)
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.updateSlot('title', DiveField.tripName);
      final slot = notifier.state.slots.firstWhere((s) => s.slotId == 'title');
      expect(slot.field, equals(DiveField.tripName));
    });

    test('updateSlot does not change other slots', () {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      final originalDate = notifier.state.slots
          .firstWhere((s) => s.slotId == 'date')
          .field;
      notifier.updateSlot('title', DiveField.tripName);
      final dateSlot = notifier.state.slots.firstWhere(
        (s) => s.slotId == 'date',
      );
      expect(dateSlot.field, equals(originalDate));
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

    test('removeExtraField is no-op when field not present', () {
      notifier.setExtraFields([DiveField.buddy]);
      notifier.removeExtraField(DiveField.waterTemp);
      expect(notifier.state.extraFields.length, equals(1));
      expect(notifier.state.extraFields.first, equals(DiveField.buddy));
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

    test('reorderExtraFields moves earlier element forward', () {
      notifier.setExtraFields([
        DiveField.buddy,
        DiveField.waterTemp,
        DiveField.airTemp,
      ]);
      notifier.reorderExtraFields(0, 3);
      expect(notifier.state.extraFields.last, equals(DiveField.buddy));
    });

    test('resetToDefault restores default config', () {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.setExtraFields([DiveField.buddy]);
      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
    });

    test('resetToDefault restores dense defaults', () {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.dense);
      notifier.setExtraFields([DiveField.buddy]);
      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
      expect(notifier.state.mode, equals(ListViewMode.dense));
    });

    test('resetToDefault restores detailed defaults', () {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.detailed);
      notifier.setExtraFields([DiveField.buddy]);
      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
      expect(notifier.state.mode, equals(ListViewMode.detailed));
    });

    test('resetToDefault uses compact when mode was never set', () {
      // Default constructor does not set _mode
      notifier.setExtraFields([DiveField.buddy]);
      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
      expect(notifier.state.mode, equals(ListViewMode.compact));
    });
  });

  group('TableViewConfigNotifier additional coverage', () {
    late TableViewConfigNotifier notifier;

    setUp(() {
      notifier = TableViewConfigNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('applyPreset replaces config with Standard preset', () {
      final presets = FieldPreset.builtInTablePresets();
      final standard = presets.firstWhere((p) => p.name == 'Standard');

      notifier.applyPreset(standard);

      final config = notifier.state;
      expect(config.columns.length, greaterThan(0));
      expect(config.columns.first.field, equals(DiveField.diveNumber));
    });

    test('toggleColumn then toggleColumn re-adds column', () {
      notifier.toggleColumn(DiveField.waterTemp);
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.waterTemp),
        isFalse,
      );

      notifier.toggleColumn(DiveField.waterTemp);
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.waterTemp),
        isTrue,
      );
    });

    test('reorderColumn moves first to last', () {
      final cols = notifier.state.columns;
      final firstField = cols.first.field;
      notifier.reorderColumn(0, cols.length);
      expect(notifier.state.columns.last.field, equals(firstField));
    });

    test('resizeColumn works for multiple fields', () {
      notifier.resizeColumn(DiveField.dateTime, 200);
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.dateTime,
      );
      expect(col.width, equals(200));

      notifier.resizeColumn(DiveField.maxDepth, 100);
      final col2 = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.maxDepth,
      );
      expect(col2.width, equals(100));
    });

    test('toggleColumn adds buddy then removes it', () {
      notifier.toggleColumn(DiveField.buddy);
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.buddy),
        isTrue,
      );

      notifier.toggleColumn(DiveField.buddy);
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.buddy),
        isFalse,
      );
    });

    test('replaceConfig clears sort', () {
      notifier.setSortField(DiveField.maxDepth);
      expect(notifier.state.sortField, isNotNull);

      final newConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        ],
      );
      notifier.replaceConfig(newConfig);

      expect(notifier.state.sortField, isNull);
    });
  });

  group('CardViewConfigNotifier additional coverage', () {
    late CardViewConfigNotifier notifier;

    setUp(() {
      notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('updateSlot for non-existent slot does nothing', () {
      final before = notifier.state.slots.length;
      notifier.updateSlot('nonexistent', DiveField.buddy);
      expect(notifier.state.slots.length, equals(before));
    });

    test('setExtraFields then resetToDefault clears them', () {
      notifier.setExtraFields([
        DiveField.buddy,
        DiveField.waterTemp,
        DiveField.airTemp,
      ]);
      expect(notifier.state.extraFields.length, equals(3));

      notifier.resetToDefault();
      expect(notifier.state.extraFields, isEmpty);
    });

    test('addExtraField then removeExtraField round-trips', () {
      notifier.addExtraField(DiveField.airTemp);
      expect(notifier.state.extraFields, contains(DiveField.airTemp));

      notifier.removeExtraField(DiveField.airTemp);
      expect(notifier.state.extraFields, isNot(contains(DiveField.airTemp)));
    });

    test('reorderExtraFields with same indices is no-op', () {
      notifier.setExtraFields([DiveField.buddy, DiveField.waterTemp]);
      notifier.reorderExtraFields(0, 1);
      expect(
        notifier.state.extraFields,
        equals([DiveField.buddy, DiveField.waterTemp]),
      );
    });

    test('withMode dense creates dense defaults', () {
      final dense = CardViewConfigNotifier.withMode(ListViewMode.dense);
      addTearDown(dense.dispose);
      expect(dense.state.mode, equals(ListViewMode.dense));
      expect(dense.state.slots, isNotEmpty);
    });
  });

  group('TableViewConfigNotifier dispose behavior', () {
    test('dispose cancels pending save timer without errors', () {
      final notifier = TableViewConfigNotifier();
      // Perform a mutation which triggers _save (creates a timer)
      notifier.toggleColumn(DiveField.buddy);
      // Dispose before timer fires -- should cancel cleanly
      notifier.dispose();
    });

    test('multiple rapid mutations do not throw', () {
      final notifier = TableViewConfigNotifier();
      notifier.toggleColumn(DiveField.buddy);
      notifier.setSortField(DiveField.maxDepth);
      notifier.resizeColumn(DiveField.siteName, 200);
      notifier.togglePin(DiveField.dateTime);
      notifier.reorderColumn(0, 2);
      notifier.dispose();
    });

    test('applyPreset triggers save path', () {
      final notifier = TableViewConfigNotifier();
      final presets = FieldPreset.builtInTablePresets();
      notifier.applyPreset(presets.first);
      notifier.dispose();
    });

    test('replaceConfig triggers save path', () {
      final notifier = TableViewConfigNotifier();
      notifier.replaceConfig(
        TableViewConfig(
          columns: [
            TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          ],
        ),
      );
      notifier.dispose();
    });
  });

  group('CardViewConfigNotifier dispose behavior', () {
    test('dispose cancels pending save timer without errors', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.updateSlot('title', DiveField.tripName);
      notifier.dispose();
    });

    test('multiple rapid mutations do not throw', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      notifier.setExtraFields([DiveField.buddy, DiveField.airTemp]);
      notifier.addExtraField(DiveField.waterTemp);
      notifier.removeExtraField(DiveField.buddy);
      notifier.reorderExtraFields(0, 1);
      notifier.resetToDefault();
      notifier.dispose();
    });

    test('withMode table falls through to detailed', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.table);
      expect(notifier.state.mode, equals(ListViewMode.detailed));
      notifier.dispose();
    });
  });

  // -----------------------------------------------------------------------
  // Provider factory tests -- exercises the provider bodies themselves
  // -----------------------------------------------------------------------

  group('Provider factories', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'tableViewConfigProvider creates notifier with default config when no diver',
      () {
        final config = container.read(tableViewConfigProvider);
        expect(config.columns, isNotEmpty);
        expect(config.columns.first.field, equals(DiveField.diveNumber));
        expect(config.sortField, isNull);
        expect(config.sortAscending, isTrue);
      },
    );

    test('tableViewConfigProvider notifier is accessible for mutations', () {
      final notifier = container.read(tableViewConfigProvider.notifier);
      notifier.toggleColumn(DiveField.buddy);
      final config = container.read(tableViewConfigProvider);
      expect(config.columns.any((c) => c.field == DiveField.buddy), isTrue);
    });

    test(
      'compactCardConfigProvider creates notifier with compact defaults',
      () {
        final config = container.read(compactCardConfigProvider);
        expect(config.slots, isNotEmpty);
        expect(config.mode, equals(ListViewMode.compact));
        expect(config.slots.first.slotId, equals('title'));
      },
    );

    test('compactCardConfigProvider notifier supports slot update', () {
      final notifier = container.read(compactCardConfigProvider.notifier);
      notifier.updateSlot('title', DiveField.maxDepth);
      final config = container.read(compactCardConfigProvider);
      final titleSlot = config.slots.firstWhere((s) => s.slotId == 'title');
      expect(titleSlot.field, equals(DiveField.maxDepth));
    });

    test('denseCardConfigProvider creates notifier with dense defaults', () {
      final config = container.read(denseCardConfigProvider);
      expect(config.slots, isNotEmpty);
      expect(config.mode, equals(ListViewMode.dense));
      expect(config.slots.first.slotId, equals('slot1'));
    });

    test('denseCardConfigProvider notifier supports slot update', () {
      final notifier = container.read(denseCardConfigProvider.notifier);
      notifier.updateSlot('slot1', DiveField.waterTemp);
      final config = container.read(denseCardConfigProvider);
      final slot1 = config.slots.firstWhere((s) => s.slotId == 'slot1');
      expect(slot1.field, equals(DiveField.waterTemp));
    });

    test(
      'detailedCardConfigProvider creates notifier with detailed defaults',
      () {
        final config = container.read(detailedCardConfigProvider);
        expect(config.slots, isNotEmpty);
        expect(config.mode, equals(ListViewMode.detailed));
      },
    );

    test('detailedCardConfigProvider notifier supports extra fields', () {
      final notifier = container.read(detailedCardConfigProvider.notifier);
      notifier.addExtraField(DiveField.buddy);
      final config = container.read(detailedCardConfigProvider);
      expect(config.extraFields, contains(DiveField.buddy));
    });

    test('detailedCardConfigProvider notifier resetToDefault works', () {
      final notifier = container.read(detailedCardConfigProvider.notifier);
      notifier.addExtraField(DiveField.buddy);
      notifier.resetToDefault();
      final config = container.read(detailedCardConfigProvider);
      expect(config.extraFields, isEmpty);
      expect(config.mode, equals(ListViewMode.detailed));
    });
  });

  // -----------------------------------------------------------------------
  // CardViewConfigNotifier save timer coverage
  // -----------------------------------------------------------------------

  group('CardViewConfigNotifier save timer', () {
    test('save timer fires without crashing when no repo is set', () async {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      addTearDown(notifier.dispose);
      // Mutate to trigger _save
      notifier.updateSlot('title', DiveField.maxDepth);
      // Wait for the debounce timer to fire (500ms)
      await Future<void>.delayed(const Duration(milliseconds: 600));
      // No assertion needed -- just exercises the timer body with null repo
    });

    test('save timer fires for dense mode without crashing', () async {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.dense);
      addTearDown(notifier.dispose);
      notifier.updateSlot('slot1', DiveField.waterTemp);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });

    test('TableViewConfigNotifier save timer fires without crashing', () async {
      final notifier = TableViewConfigNotifier();
      addTearDown(notifier.dispose);
      notifier.toggleColumn(DiveField.buddy);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
  });

  // -----------------------------------------------------------------------
  // CardViewConfigNotifier._defaultForMode static coverage
  // -----------------------------------------------------------------------

  group('CardViewConfigNotifier _defaultForMode coverage', () {
    test('compact mode returns compact defaults', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      addTearDown(notifier.dispose);
      expect(notifier.state.mode, equals(ListViewMode.compact));
      expect(notifier.state.slots, hasLength(4));
    });

    test('dense mode returns dense defaults', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.dense);
      addTearDown(notifier.dispose);
      expect(notifier.state.mode, equals(ListViewMode.dense));
      expect(notifier.state.slots, hasLength(4));
    });

    test('detailed mode returns detailed defaults', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.detailed);
      addTearDown(notifier.dispose);
      expect(notifier.state.mode, equals(ListViewMode.detailed));
    });

    test('table mode falls through to detailed defaults', () {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.table);
      addTearDown(notifier.dispose);
      expect(notifier.state.mode, equals(ListViewMode.detailed));
    });
  });
}
