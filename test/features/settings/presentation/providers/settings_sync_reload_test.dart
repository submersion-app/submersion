import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Holds every settings write until [gate] completes, so a test can keep a
/// local save in flight while a sync lands.
class _GatedWriteRepository extends DiverSettingsRepository {
  Completer<void>? gate;

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings, {
    AppSettings? previous,
  }) async {
    final held = gate;
    if (held != null) await held.future;
    return super.updateSettingsForDiver(diverId, settings, previous: previous);
  }
}

/// Settings another device changed reach this device's [settingsProvider]
/// when a sync applies them, and a later local change keeps them (issue
/// #2946).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _GatedWriteRepository settingsRepository;
  late String diverA;
  late String diverB;

  Future<String> createDiver(String name) async {
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: name, createdAt: now, updatedAt: now),
    );
    await DiverSettingsRepository().getOrCreateSettingsForDiver(diver.id);
    return diver.id;
  }

  /// Applies a peer's newer copy of [diverId]'s row the way sync does: an
  /// upsert of the whole row.
  Future<void> applyPeerRow(
    String diverId,
    DiverSetting Function(DiverSetting row) change,
  ) async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.diverId.equals(diverId))).getSingle();
    final peer = change(
      row,
    ).copyWith(updatedAt: row.updatedAt + 1000, hlc: const Value('peer-clock'));
    await db
        .into(db.diverSettings)
        .insertOnConflictUpdate(peer.toCompanion(false));
  }

  Future<AppSettings?> storedSettings(String diverId) =>
      DiverSettingsRepository().getSettingsForDiver(diverId);

  setUp(() async {
    db = await setUpTestDatabase();
    diverA = await createDiver('A');
    diverB = await createDiver('B');
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverA});
    final prefs = await SharedPreferences.getInstance();
    settingsRepository = _GatedWriteRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverSettingsRepositoryProvider.overrideWithValue(settingsRepository),
      ],
    );
    await container.read(settingsProvider.notifier).settingsLoaded;
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('a synced change to the active diver reloads the settings', () async {
    expect(container.read(settingsProvider).gfHigh, 85);

    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 70));
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 70);
  });

  test('a synced change keeps device-local preferences', () async {
    await container.read(settingsProvider.notifier).setPscrRatio(40);

    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 70));
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 70);
    expect(container.read(settingsProvider).pscrRatio, 40);
  });

  test('a synced change to another diver leaves the settings alone', () async {
    await applyPeerRow(diverB, (row) => row.copyWith(gfHigh: 70));
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 85);
  });

  test('a local change after a synced one keeps the synced change', () async {
    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 70));
    await container
        .read(settingsProvider.notifier)
        .setDepthUnit(DepthUnit.feet);
    await pumpEventQueue();

    final stored = await storedSettings(diverA);
    expect(stored!.gfHigh, 70, reason: 'the local save reverted GF high');
    expect(stored.depthUnit, DepthUnit.feet);
    expect(container.read(settingsProvider).gfHigh, 70);
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
  });

  test('a sync landing while a local save is in flight keeps both', () async {
    final gate = settingsRepository.gate = Completer<void>();
    final saving = container
        .read(settingsProvider.notifier)
        .setDepthUnit(DepthUnit.feet);

    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 70));
    await pumpEventQueue();
    expect(
      container.read(settingsProvider).depthUnit,
      DepthUnit.feet,
      reason: 'the sync reload discarded an edit whose save was in flight',
    );

    gate.complete();
    await saving;
    await pumpEventQueue();

    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    expect(container.read(settingsProvider).gfHigh, 70);
    final stored = await storedSettings(diverA);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.gfHigh, 70);
  });

  test('a synced change follows a diver switch', () async {
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverB);
    await container.read(settingsProvider.notifier).settingsLoaded;

    await applyPeerRow(diverB, (row) => row.copyWith(gfHigh: 70));
    await applyPeerRow(diverA, (row) => row.copyWith(gfHigh: 60));
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 70);
  });
}
