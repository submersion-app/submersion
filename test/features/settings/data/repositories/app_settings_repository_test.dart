import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppSettingsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = AppSettingsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('AppSettingsRepository.getShareByDefault', () {
    test('returns false when key is absent', () async {
      expect(await repository.getShareByDefault(), isFalse);
    });

    test('round-trips true', () async {
      await repository.setShareByDefault(true);
      expect(await repository.getShareByDefault(), isTrue);
    });

    test('round-trips false after being set to true', () async {
      await repository.setShareByDefault(true);
      await repository.setShareByDefault(false);
      expect(await repository.getShareByDefault(), isFalse);
    });
  });

  group('AppSettingsRepository.getBlenderPreferences', () {
    test('returns null when never written', () async {
      expect(await repository.getBlenderPreferences(), isNull);
    });

    test('round-trips the last-entered calculator values', () async {
      // Issue #1335: the cylinder, target fill and fill gases used to reset
      // on every open. This is the persistence path that closes that gap.
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            startPressureBar: 40,
            startMix: const GasMix(o2: 14.5, he: 57.2),
            targetPressureBar: 220,
            targetMix: const GasMix(o2: 15, he: 55),
            topupO2Percent: 20.9,
            fillOrder: const [
              BlenderGasRole.he,
              BlenderGasRole.o2,
              BlenderGasRole.topup,
            ],
          );

      await repository.setBlenderPreferences(prefs);
      final loaded = await repository.getBlenderPreferences();

      expect(loaded, isNotNull);
      expect(loaded!.startPressureBar, 40);
      expect(loaded.startMix, const GasMix(o2: 14.5, he: 57.2));
      expect(loaded.targetPressureBar, 220);
      expect(loaded.targetMix, const GasMix(o2: 15, he: 55));
      expect(loaded.topupO2Percent, 20.9);
      expect(loaded.fillOrder, [
        BlenderGasRole.he,
        BlenderGasRole.o2,
        BlenderGasRole.topup,
      ]);
    });

    test('a later write overwrites the earlier one', () async {
      await repository.setBlenderPreferences(
        BlenderPreferences.defaults(
          cylinderWaterLiters: 12,
        ).copyWith(startPressureBar: 40),
      );
      await repository.setBlenderPreferences(
        BlenderPreferences.defaults(
          cylinderWaterLiters: 12,
        ).copyWith(startPressureBar: 90),
      );

      final loaded = await repository.getBlenderPreferences();
      expect(loaded!.startPressureBar, 90);
    });

    test('setBlenderPreferences stages the row for sync', () async {
      await repository.setBlenderPreferences(
        BlenderPreferences.defaults(cylinderWaterLiters: 12),
      );

      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.any(
          (r) =>
              r.entityType == 'settings' && r.recordId == 'gas_blender_prefs',
        ),
        isTrue,
      );
    });
  });

  group('AppSettingsRepository sync notifications', () {
    // Marking the settings row pending only stages it; the change bus is what
    // schedules on-change auto-sync. Regression for the missing bus calls.
    test('setShareByDefault notifies the sync change bus', () async {
      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.setShareByDefault(true);
      await pumpEventQueue();

      expect(fired, isTrue);
    });

    test('setNavPrimaryIds notifies the sync change bus', () async {
      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.setNavPrimaryIds(const ['a', 'b']);
      await pumpEventQueue();

      expect(fired, isTrue);
    });
  });

  group('AppSettingsRepository raw settings', () {
    test('returns null for an absent key', () async {
      expect(await repository.getRawSetting('nope'), isNull);
    });

    test('round-trips a value', () async {
      await repository.setRawSetting('k', 'v');
      expect(await repository.getRawSetting('k'), 'v');
    });

    test('overwrites an existing value', () async {
      await repository.setRawSetting('k', 'v1');
      await repository.setRawSetting('k', 'v2');
      expect(await repository.getRawSetting('k'), 'v2');
    });

    test('keys are independent', () async {
      await repository.setRawSetting('a', '1');
      await repository.setRawSetting('b', '2');
      expect(await repository.getRawSetting('a'), '1');
      expect(await repository.getRawSetting('b'), '2');
    });

    // This is the assertion that proves the value actually syncs: staging the
    // row under entityType 'settings' with the key as recordId is what puts it
    // into the next changeset.
    test('setRawSetting stages the row for sync under its key', () async {
      await repository.setRawSetting('k', 'v');

      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.any((r) => r.entityType == 'settings' && r.recordId == 'k'),
        isTrue,
      );
    });

    test('setRawSetting notifies the sync change bus', () async {
      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.setRawSetting('k', 'v');
      await pumpEventQueue();

      expect(fired, isTrue);
    });
  });
}
