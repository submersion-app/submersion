import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.hiddenTankPresetIds', () {
    test('defaults to empty, so every built-in preset starts visible', () {
      const settings = AppSettings();
      expect(settings.hiddenTankPresetIds, isEmpty);
    });

    test('copyWith carries the set', () {
      const settings = AppSettings();
      final updated = settings.copyWith(hiddenTankPresetIds: const {'al80'});
      expect(updated.hiddenTankPresetIds, {'al80'});
      // Unrelated settings survive.
      expect(updated.defaultTankPreset, settings.defaultTankPreset);
    });
  });

  group('DiverSettingsRepository hidden tank preset persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    Future<void> storeRaw(String? raw) => db.customUpdate(
      'UPDATE diver_settings SET hidden_tank_preset_ids = ? '
      "WHERE diver_id = 'd1'",
      variables: [Variable<String>(raw)],
    );

    test('new settings default to none hidden', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, isEmpty);
    });

    test('creating settings with hidden presets stores them', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(hiddenTankPresetIds: {'hp80', 'al40'}),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, {'hp80', 'al40'});
    });

    test('round-trips a set with several presets', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(hiddenTankPresetIds: {'al80', 'lp85'}),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, {'al80', 'lp85'});
    });

    test('clearing back to empty stores null', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(hiddenTankPresetIds: {'al80'}),
      );
      await repository.updateSettingsForDiver('d1', const AppSettings());
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, isEmpty);
      final row = await db
          .customSelect(
            "SELECT hidden_tank_preset_ids FROM diver_settings "
            "WHERE diver_id = 'd1'",
          )
          .getSingle();
      expect(row.read<String?>('hidden_tank_preset_ids'), isNull);
    });

    test('malformed stored JSON degrades to empty, never throws', () async {
      await repository.createSettingsForDiver('d1');
      await storeRaw('not json');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, isEmpty);
    });

    test('a non-list JSON value degrades to empty', () async {
      await repository.createSettingsForDiver('d1');
      await storeRaw('{"al80": true}');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, isEmpty);
    });

    test('non-string entries are dropped, the rest survive', () async {
      await repository.createSettingsForDiver('d1');
      await storeRaw('["al80", 42, null, "hp100"]');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.hiddenTankPresetIds, {'al80', 'hp100'});
    });
  });
}
