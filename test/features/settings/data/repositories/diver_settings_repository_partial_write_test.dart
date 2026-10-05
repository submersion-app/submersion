import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// A diver's settings row merges across devices as a whole, last writer wins.
/// A write that re-stamps every column from a stale in-memory copy therefore
/// undoes whatever a peer changed since that copy was read (issue #2946).
/// Given the settings the caller last stored, the repository writes only the
/// columns the caller changed.
void main() {
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

  tearDown(tearDownTestDatabase);

  /// Stands in for a sync applying a peer's newer copy of the row.
  Future<void> applyPeerGfHigh(int gfHigh) =>
      (db.update(db.diverSettings)..where((t) => t.diverId.equals('d1'))).write(
        DiverSettingsCompanion(gfHigh: Value(gfHigh)),
      );

  Future<DiverSetting> storedRow() => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals('d1'))).getSingle();

  test('a change from a stale copy keeps the columns a peer changed', () async {
    final stale = await repository.createSettingsForDiver('d1');
    expect(stale.gfHigh, 85);
    await applyPeerGfHigh(70);

    await repository.updateSettingsForDiver(
      'd1',
      stale.copyWith(depthUnit: DepthUnit.feet),
      previous: stale,
    );

    final stored = await repository.getSettingsForDiver('d1');
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.gfHigh, 70, reason: "the stale copy undid the peer's change");
  });

  test('an unchanged copy writes nothing and queues nothing to sync', () async {
    final settings = await repository.createSettingsForDiver('d1');
    final before = await storedRow();
    final pendingBefore = await SyncRepository().getPendingRecords();

    await repository.updateSettingsForDiver('d1', settings, previous: settings);

    final after = await storedRow();
    expect(after.updatedAt, before.updatedAt);
    expect(after.hlc, before.hlc);
    expect(
      (await SyncRepository().getPendingRecords()).length,
      pendingBefore.length,
    );
  });

  test('a change re-stamps the row and queues it to sync', () async {
    final settings = await repository.createSettingsForDiver('d1');
    final before = await storedRow();

    await repository.updateSettingsForDiver(
      'd1',
      settings.copyWith(gfLow: 40),
      previous: settings,
    );

    final after = await storedRow();
    expect(after.gfLow, 40);
    expect(after.updatedAt, greaterThanOrEqualTo(before.updatedAt));
    expect(after.hlc, isNot(before.hlc));
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.where(
        (r) => r.entityType == 'diverSettings' && r.recordId == after.id,
      ),
      isNotEmpty,
    );
  });

  test('a device-local change stamps no clock and queues nothing', () async {
    final settings = await repository.createSettingsForDiver('d1');
    final before = await storedRow();
    final pendingBefore = await SyncRepository().getPendingRecords();

    await repository.updateSettingsForDiver(
      'd1',
      settings.copyWith(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        reminderTime: const TimeOfDay(hour: 6, minute: 15),
      ),
      previous: settings,
    );

    final after = await storedRow();
    expect(after.themeMode, 'dark');
    expect(after.notificationsEnabled, isFalse);
    expect(after.reminderTime, '06:15');
    expect(after.updatedAt, before.updatedAt);
    expect(after.hlc, before.hlc);
    expect(
      (await SyncRepository().getPendingRecords()).length,
      pendingBefore.length,
    );
  });

  test(
    'a change mixing device-local and synced columns stamps and queues',
    () async {
      final settings = await repository.createSettingsForDiver('d1');
      final before = await storedRow();

      await repository.updateSettingsForDiver(
        'd1',
        settings.copyWith(themeMode: ThemeMode.dark, gfLow: 40),
        previous: settings,
      );

      final after = await storedRow();
      expect(after.themeMode, 'dark');
      expect(after.gfLow, 40);
      expect(after.hlc, isNot(before.hlc));
      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.where(
          (r) => r.entityType == 'diverSettings' && r.recordId == after.id,
        ),
        isNotEmpty,
      );
    },
  );

  test('without a previous copy every column is written', () async {
    final settings = await repository.createSettingsForDiver('d1');
    await applyPeerGfHigh(70);

    await repository.updateSettingsForDiver(
      'd1',
      settings.copyWith(depthUnit: DepthUnit.feet),
    );

    final stored = await repository.getSettingsForDiver('d1');
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.gfHigh, 85);
  });

  test('storesSameSettings compares only what the row stores', () {
    const base = AppSettings();
    expect(
      DiverSettingsRepository.storesSameSettings(
        base,
        base.copyWith(pscrRatio: 50),
      ),
      isTrue,
      reason: 'pSCR ratio is a device-local preference, not a column',
    );
    expect(
      DiverSettingsRepository.storesSameSettings(
        base,
        base.copyWith(gfHigh: 70),
      ),
      isFalse,
    );
  });
}
