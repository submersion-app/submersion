import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
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
