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

/// Holds a diver's settings read until that diver's gate completes, so a test
/// can keep one load in flight while another starts and finishes.
class _GatedSettingsRepository extends DiverSettingsRepository {
  final gates = <String, Completer<void>>{};

  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    final gate = gates[diverId];
    if (gate != null) await gate.future;
    return super.getOrCreateSettingsForDiver(
      diverId,
      defaultSettings: defaultSettings,
    );
  }
}

/// After a diver switch [SettingsNotifier] keeps the previous diver's settings
/// in [state] until the new diver's row is read (issue #2564). Analyses whose
/// results are saved (the safety review, the deco classification cache) wait
/// on [SettingsNotifier.settingsLoaded], so it must cover that reload, and a
/// superseded load must never finish last and leave another diver's settings.
void main() {
  late ProviderContainer container;
  late _GatedSettingsRepository settingsRepository;
  late String diverA;
  late String diverB;
  late String diverC;

  Future<String> createDiver(String name, int gfLow) async {
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: name, createdAt: now, updatedAt: now),
    );
    final repository = DiverSettingsRepository();
    final stored = await repository.getOrCreateSettingsForDiver(diver.id);
    await repository.updateSettingsForDiver(
      diver.id,
      stored.copyWith(gfLow: gfLow),
    );
    return diver.id;
  }

  setUp(() async {
    await setUpTestDatabase();
    diverA = await createDiver('A', 20);
    diverB = await createDiver('B', 35);
    diverC = await createDiver('C', 50);
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverA});
    final prefs = await SharedPreferences.getInstance();
    settingsRepository = _GatedSettingsRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverSettingsRepositoryProvider.overrideWithValue(settingsRepository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<void> switchTo(String diverId) =>
      container.read(currentDiverIdProvider.notifier).setCurrentDiver(diverId);

  test(
    "settingsLoaded waits for the new diver's settings after a switch",
    () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.settingsLoaded;
      expect(container.read(settingsProvider).gfLow, 20);

      final gateB = settingsRepository.gates[diverB] = Completer<void>();
      await switchTo(diverB);

      var loaded = false;
      final waiting = notifier.settingsLoaded.then((_) => loaded = true);
      await pumpEventQueue();
      expect(
        loaded,
        isFalse,
        reason: "settingsLoaded completed while state still held A's settings",
      );
      expect(container.read(settingsProvider).gfLow, 20);

      gateB.complete();
      await waiting;
      expect(container.read(settingsProvider).gfLow, 35);
    },
  );

  test('a superseded load that finishes last does not overwrite the current '
      "diver's settings", () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.settingsLoaded;

    // B's read is slow; the user moves on to C before it returns.
    final gateB = settingsRepository.gates[diverB] = Completer<void>();
    await switchTo(diverB);
    await pumpEventQueue();
    await switchTo(diverC);
    await notifier.settingsLoaded;
    await pumpEventQueue();
    expect(container.read(settingsProvider).gfLow, 50);

    // B's read returns only now, after C's has landed.
    gateB.complete();
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfLow, 50);
  });

  // The post-restore safety sweep awaits initialLoad on a fresh container,
  // where the active diver id can be realigned while the first load is still
  // out. The superseded first load returns without writing state, so
  // initialLoad must follow the load that replaced it rather than resolve on
  // the defaults.
  test('initialLoad follows a load that supersedes the first one', () async {
    final gateA = settingsRepository.gates[diverA] = Completer<void>();
    final gateB = settingsRepository.gates[diverB] = Completer<void>();
    final notifier = container.read(settingsProvider.notifier);
    await pumpEventQueue();
    await switchTo(diverB);

    var loaded = false;
    final waiting = notifier.initialLoad.then((_) => loaded = true);
    gateA.complete();
    await pumpEventQueue();
    expect(
      loaded,
      isFalse,
      reason: 'initialLoad resolved on the superseded load, on the defaults',
    );

    gateB.complete();
    await waiting;
    expect(container.read(settingsProvider).gfLow, 35);
  });

  test('a wait begun during a superseded load resolves only on the current '
      "diver's settings", () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.settingsLoaded;

    final gateB = settingsRepository.gates[diverB] = Completer<void>();
    await switchTo(diverB);
    final startedDuringB = notifier.settingsLoaded;

    final gateC = settingsRepository.gates[diverC] = Completer<void>();
    await switchTo(diverC);
    gateB.complete();

    var loaded = false;
    unawaited(startedDuringB.then((_) => loaded = true));
    await pumpEventQueue();
    expect(
      loaded,
      isFalse,
      reason: "the wait resolved on B's abandoned load while C's was pending",
    );

    gateC.complete();
    await startedDuringB;
    expect(container.read(settingsProvider).gfLow, 50);
  });
}
