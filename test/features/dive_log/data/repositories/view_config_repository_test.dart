import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart' hide FieldPreset;
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

void main() {
  late AppDatabase db;
  late ViewConfigRepository repository;
  const testDiverId = 'diver-test-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = ViewConfigRepository(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(testDiverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ViewConfigRepository', () {
    group('getTableConfig', () {
      test('returns default config when nothing is saved', () async {
        final config = await repository.getTableConfig(testDiverId);

        final defaultConfig = TableViewConfig.defaultConfig();
        expect(config.columns.length, equals(defaultConfig.columns.length));
        expect(config.sortField, isNull);
        expect(config.sortAscending, isTrue);
        expect(
          config.columns.map((c) => c.field).toList(),
          equals(defaultConfig.columns.map((c) => c.field).toList()),
        );
      });
    });

    group('saveTableConfig and getTableConfig', () {
      test('persists config and can be retrieved', () async {
        final config = TableViewConfig.defaultConfig().copyWith(
          sortAscending: false,
        );

        await repository.saveTableConfig(testDiverId, config);
        final retrieved = await repository.getTableConfig(testDiverId);

        expect(retrieved.sortAscending, isFalse);
        expect(retrieved.columns.length, equals(config.columns.length));
      });

      test('updates existing config on second save', () async {
        final first = TableViewConfig.defaultConfig();
        await repository.saveTableConfig(testDiverId, first);

        final second = first.copyWith(sortAscending: false);
        await repository.saveTableConfig(testDiverId, second);

        final retrieved = await repository.getTableConfig(testDiverId);
        expect(retrieved.sortAscending, isFalse);

        final rows = await db.select(db.viewConfigs).get();
        expect(rows.where((r) => r.viewMode == 'table').length, equals(1));
      });
    });

    group('getCardConfig', () {
      test('returns default compact config when nothing is saved', () async {
        final config = await repository.getCardConfig(
          testDiverId,
          ListViewMode.compact,
        );

        final defaultConfig = CardViewConfig.defaultCompact();
        expect(config.mode, equals(ListViewMode.compact));
        expect(config.slots.length, equals(defaultConfig.slots.length));
      });

      test('returns default dense config when nothing is saved', () async {
        final config = await repository.getCardConfig(
          testDiverId,
          ListViewMode.dense,
        );

        expect(config.mode, equals(ListViewMode.dense));
      });

      test('returns default detailed config when nothing is saved', () async {
        final config = await repository.getCardConfig(
          testDiverId,
          ListViewMode.detailed,
        );

        expect(config.mode, equals(ListViewMode.detailed));
      });
    });

    group('saveCardConfig and getCardConfig', () {
      test('persists compact card config and retrieves it', () async {
        final config = CardViewConfig.defaultCompact().copyWith(
          slots: [
            const CardSlotConfig(slotId: 'title', field: DiveField.diveNumber),
            const CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
          ],
        );

        await repository.saveCardConfig(testDiverId, config);
        final retrieved = await repository.getCardConfig(
          testDiverId,
          ListViewMode.compact,
        );

        expect(retrieved.mode, equals(ListViewMode.compact));
        expect(retrieved.slots.length, equals(2));
        expect(retrieved.slots[0].field, equals(DiveField.diveNumber));
      });

      test('updates existing card config on second save', () async {
        final first = CardViewConfig.defaultCompact();
        await repository.saveCardConfig(testDiverId, first);

        final second = first.copyWith(
          slots: [
            const CardSlotConfig(slotId: 'title', field: DiveField.diveNumber),
          ],
        );
        await repository.saveCardConfig(testDiverId, second);

        final retrieved = await repository.getCardConfig(
          testDiverId,
          ListViewMode.compact,
        );
        expect(retrieved.slots.length, equals(1));

        final rows = await db.select(db.viewConfigs).get();
        expect(rows.where((r) => r.viewMode == 'compact').length, equals(1));
      });
    });

    group('ensureBuiltInPresets and getPresetsForMode', () {
      test('returns built-in presets after ensureBuiltInPresets', () async {
        await repository.ensureBuiltInPresets(testDiverId);

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.table,
        );

        expect(presets.isNotEmpty, isTrue);
        expect(presets.any((p) => p.isBuiltIn), isTrue);
        expect(presets.any((p) => p.name == 'Standard'), isTrue);
        expect(presets.any((p) => p.name == 'Technical'), isTrue);
        expect(presets.any((p) => p.name == 'Planning'), isTrue);
      });

      test(
        'calling ensureBuiltInPresets twice does not duplicate presets',
        () async {
          await repository.ensureBuiltInPresets(testDiverId);
          await repository.ensureBuiltInPresets(testDiverId);

          final presets = await repository.getPresetsForMode(
            testDiverId,
            ListViewMode.table,
          );

          final standardPresets = presets
              .where((p) => p.name == 'Standard')
              .toList();
          expect(standardPresets.length, equals(1));
        },
      );

      test('returns empty list when no presets for mode', () async {
        await repository.ensureBuiltInPresets(testDiverId);

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.compact,
        );

        expect(presets, isEmpty);
      });
    });

    group('savePreset', () {
      test('creates a user preset', () async {
        final preset = FieldPreset(
          id: 'user-preset-1',
          name: 'My Custom Preset',
          viewMode: ListViewMode.table,
          configJson: TableViewConfig.defaultConfig().toJson(),
          isBuiltIn: false,
        );

        await repository.savePreset(testDiverId, preset);

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.table,
        );

        expect(presets.any((p) => p.id == 'user-preset-1'), isTrue);
        expect(
          presets.firstWhere((p) => p.id == 'user-preset-1').name,
          equals('My Custom Preset'),
        );
        expect(
          presets.firstWhere((p) => p.id == 'user-preset-1').isBuiltIn,
          isFalse,
        );
      });

      test('updates existing preset on conflict', () async {
        final preset = FieldPreset(
          id: 'user-preset-1',
          name: 'My Preset',
          viewMode: ListViewMode.table,
          configJson: TableViewConfig.defaultConfig().toJson(),
        );
        await repository.savePreset(testDiverId, preset);

        final updated = preset.copyWith(name: 'Renamed Preset');
        await repository.savePreset(testDiverId, updated);

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.table,
        );
        final found = presets.firstWhere((p) => p.id == 'user-preset-1');
        expect(found.name, equals('Renamed Preset'));
      });
    });

    group('getRawConfig and saveRawConfig', () {
      test('returns null when no raw config is saved', () async {
        final result = await repository.getRawConfig(
          testDiverId,
          'table_sites',
        );
        expect(result, isNull);
      });

      test('saves and retrieves raw config', () async {
        const key = 'table_trips';
        const configJson = '{"columns":[{"field":"tripName","width":150}]}';

        await repository.saveRawConfig(testDiverId, key, configJson);
        final result = await repository.getRawConfig(testDiverId, key);

        expect(result, equals(configJson));
      });

      test('updates existing raw config on second save', () async {
        const key = 'table_buddies';
        const first = '{"columns":[]}';
        const second = '{"columns":[{"field":"buddyName","width":120}]}';

        await repository.saveRawConfig(testDiverId, key, first);
        await repository.saveRawConfig(testDiverId, key, second);

        final result = await repository.getRawConfig(testDiverId, key);
        expect(result, equals(second));

        // Verify only one row exists for this key
        final rows = await db.select(db.viewConfigs).get();
        expect(rows.where((r) => r.viewMode == key).length, equals(1));
      });
    });

    group('getCardConfig table mode', () {
      test(
        'returns detailed defaults when table mode has no saved config',
        () async {
          final config = await repository.getCardConfig(
            testDiverId,
            ListViewMode.table,
          );

          // table mode falls through to detailed defaults
          expect(config.mode, equals(ListViewMode.detailed));
        },
      );
    });

    group('deletePreset', () {
      test('removes a user preset', () async {
        final preset = FieldPreset(
          id: 'user-preset-del',
          name: 'To Delete',
          viewMode: ListViewMode.table,
          configJson: TableViewConfig.defaultConfig().toJson(),
          isBuiltIn: false,
        );

        await repository.savePreset(testDiverId, preset);
        await repository.deletePreset('user-preset-del');

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.table,
        );
        expect(presets.any((p) => p.id == 'user-preset-del'), isFalse);
      });

      test('does not delete a built-in preset', () async {
        await repository.ensureBuiltInPresets(testDiverId);

        await repository.deletePreset('builtin_standard');

        final presets = await repository.getPresetsForMode(
          testDiverId,
          ListViewMode.table,
        );
        expect(presets.any((p) => p.id == 'builtin_standard'), isTrue);
      });
    });
  });
}
