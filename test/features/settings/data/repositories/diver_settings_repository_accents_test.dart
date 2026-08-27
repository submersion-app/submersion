import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiverSettingsRepository color accent persistence', () {
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

    test('new settings default to all accents off', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.accentNavIcons, isFalse);
      expect(loaded.accentSectionHeaders, isFalse);
      expect(loaded.accentListIcons, isFalse);
    });

    test('round-trips all three accent toggles through update', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          accentNavIcons: true,
          accentSectionHeaders: true,
          accentListIcons: true,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.accentNavIcons, isTrue);
      expect(loaded.accentSectionHeaders, isTrue);
      expect(loaded.accentListIcons, isTrue);
    });

    // Each toggle must map to its own column. Three near-identical booleans
    // are exactly where a copy-paste error wires two fields to one column,
    // so set each one alone and assert the other two stay off.
    test('accentNavIcons persists independently', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(accentNavIcons: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.accentNavIcons, isTrue);
      expect(loaded.accentSectionHeaders, isFalse);
      expect(loaded.accentListIcons, isFalse);
    });

    test('accentSectionHeaders persists independently', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(accentSectionHeaders: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.accentSectionHeaders, isTrue);
      expect(loaded.accentNavIcons, isFalse);
      expect(loaded.accentListIcons, isFalse);
    });

    test('accentListIcons persists independently', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(accentListIcons: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.accentListIcons, isTrue);
      expect(loaded.accentNavIcons, isFalse);
      expect(loaded.accentSectionHeaders, isFalse);
    });

    test(
      'createSettingsForDiver carries seeded accents into the row',
      () async {
        await repository.createSettingsForDiver(
          'd1',
          settings: const AppSettings(accentNavIcons: true),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.accentNavIcons, isTrue);
        expect(loaded.accentSectionHeaders, isFalse);
        expect(loaded.accentListIcons, isFalse);
      },
    );
  });
}
