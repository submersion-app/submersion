import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Holds each diver's settings load at its first read until that diver's
/// gate completes, so a test can order two overlapping loads by hand.
class _GatedDiverRepository extends DiverRepository {
  final gates = <String, Completer<void>>{};

  Completer<void> gateFor(String diverId) =>
      gates.putIfAbsent(diverId, Completer<void>.new);

  @override
  Future<Diver?> getDiverById(String id) async {
    await gateFor(id).future;
    return super.getDiverById(id);
  }
}

/// Issue #2564: after a diver switch, [SettingsNotifier] keeps the previous
/// diver's settings in state until the new diver's row is read. An analysis
/// that waited only for the first load ran on the previous diver's gradient
/// factors in that window, and its result was persisted.
void main() {
  late ProviderContainer container;
  late _GatedDiverRepository divers;
  late String diverA;
  late String diverB;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final repo = DiverRepository();
    diverA = (await repo.createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    )).id;
    diverB = (await repo.createDiver(
      Diver(id: '', name: 'B', createdAt: now, updatedAt: now),
    )).id;
    final settingsRepo = DiverSettingsRepository();
    await settingsRepo.getOrCreateSettingsForDiver(diverA);
    await settingsRepo.updateSettingsForDiver(
      diverA,
      const AppSettings(gfLow: 30, gfHigh: 70),
    );
    await settingsRepo.getOrCreateSettingsForDiver(diverB);
    await settingsRepo.updateSettingsForDiver(
      diverB,
      const AppSettings(gfLow: 50, gfHigh: 85),
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverA});
    final prefs = await SharedPreferences.getInstance();
    divers = _GatedDiverRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverRepositoryProvider.overrideWithValue(divers),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('loaded waits for the switched-to diver, not the first load', () async {
    final notifier = container.read(settingsProvider.notifier);
    divers.gateFor(diverA).complete();
    await notifier.loaded;
    expect(container.read(settingsProvider).gfLow, 30);

    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverB);

    var settled = false;
    unawaited(notifier.loaded.then((_) => settled = true));
    await pumpEventQueue();
    expect(
      settled,
      isFalse,
      reason: "B's settings have not been read yet, so nothing has loaded",
    );
    expect(
      container.read(settingsProvider).gfLow,
      30,
      reason: "the window: state still holds A's settings",
    );

    divers.gateFor(diverB).complete();
    await notifier.loaded;
    expect(container.read(settingsProvider).gfLow, 50);
    expect(container.read(settingsProvider).gfHigh, 85);
  });

  test('a slower earlier load finishing last does not restore the previous '
      "diver's settings", () async {
    final notifier = container.read(settingsProvider.notifier);
    // A's first load is still waiting on its diver read when B is chosen.
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverB);

    divers.gateFor(diverB).complete();
    await notifier.loaded;
    expect(container.read(settingsProvider).gfLow, 50);

    // A's load now finishes, after B's.
    divers.gateFor(diverA).complete();
    try {
      await notifier.initialLoad;
    } catch (_) {
      // Only its completion matters here.
    }
    await pumpEventQueue();

    expect(
      container.read(settingsProvider).gfLow,
      50,
      reason: "A's stale load must not overwrite B's settings",
    );
    expect(container.read(settingsProvider).gfHigh, 85);
  });
}
