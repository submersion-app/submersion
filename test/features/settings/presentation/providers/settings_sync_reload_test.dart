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

/// Holds settings writes and reads until a test releases them, so it can
/// keep a local save or a diver's load in flight while something else lands.
class _GatedRepository extends DiverSettingsRepository {
  /// Each write waits on the next gate in line, if any.
  final writeGates = <Completer<void>>[];

  /// A diver's settings read waits on that diver's gate, if any.
  final readGates = <String, Completer<void>>{};

  /// How many of the next writes throw instead of writing.
  int failingWrites = 0;

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings, {
    AppSettings? previous,
  }) async {
    if (writeGates.isNotEmpty) await writeGates.removeAt(0).future;
    if (failingWrites > 0) {
      failingWrites--;
      throw StateError('settings write failed');
    }
    return super.updateSettingsForDiver(diverId, settings, previous: previous);
  }

  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    final gate = readGates[diverId];
    if (gate != null) await gate.future;
    return super.getOrCreateSettingsForDiver(
      diverId,
      defaultSettings: defaultSettings,
    );
  }
}

/// Settings another device changed reach this device's [settingsProvider]
/// when a sync applies them, and a later local change keeps them (issue
/// #2946).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _GatedRepository settingsRepository;
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
    settingsRepository = _GatedRepository();
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
    final gate = Completer<void>();
    settingsRepository.writeGates.add(gate);
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

  test('overlapping saves land in the order they were made', () async {
    final notifier = container.read(settingsProvider.notifier);
    final slowWrite = Completer<void>();
    settingsRepository.writeGates.add(slowWrite);

    // Not awaited, as a slider or a settings tile may call them.
    final first = notifier.setGfHigh(80);
    final second = notifier.setGfHigh(75);
    await pumpEventQueue();
    slowWrite.complete();
    await Future.wait([first, second]);
    await pumpEventQueue();

    expect(container.read(settingsProvider).gfHigh, 75);
    final stored = await storedSettings(diverA);
    expect(stored!.gfHigh, 75, reason: 'the earlier save landed last');
  });

  test(
    "a change made mid-switch never lands in the next diver's row",
    () async {
      await applyPeerRow(diverB, (row) => row.copyWith(gfHigh: 70));
      final readB = settingsRepository.readGates[diverB] = Completer<void>();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(diverB);
      await pumpEventQueue();
      // B's row is being read; [state] still holds A's settings.
      expect(container.read(settingsProvider).gfHigh, 85);

      await container
          .read(settingsProvider.notifier)
          .setDepthUnit(DepthUnit.feet);
      readB.complete();
      await container.read(settingsProvider.notifier).settingsLoaded;
      await pumpEventQueue();

      final stored = await storedSettings(diverB);
      expect(stored!.gfHigh, 70, reason: "A's settings overwrote B's row");
      expect(container.read(settingsProvider).gfHigh, 70);
    },
  );

  test('a save after a failed one stores the change that failed', () async {
    final notifier = container.read(settingsProvider.notifier);
    final slowWrite = Completer<void>();
    settingsRepository.writeGates.add(slowWrite);
    settingsRepository.failingWrites = 1;

    final failed = expectLater(notifier.setGfHigh(70), throwsStateError);
    final second = notifier.setDepthUnit(DepthUnit.feet);
    await pumpEventQueue();
    slowWrite.complete();
    await failed;
    await second;
    await pumpEventQueue();

    // [state] still shows the change, so the row must hold it too.
    expect(container.read(settingsProvider).gfHigh, 70);
    final stored = await storedSettings(diverA);
    expect(stored!.gfHigh, 70, reason: 'the change that failed was dropped');
    expect(stored.depthUnit, DepthUnit.feet);
  });
}
