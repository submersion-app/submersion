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

/// Holds the settings load at its first read until [gate] completes, so a
/// test can act inside the window where [SettingsNotifier] still holds its
/// defaults.
class _GatedDiverRepository extends DiverRepository {
  _GatedDiverRepository(this.gate);

  final Completer<void> gate;

  @override
  Future<Diver?> getDiverById(String id) async {
    await gate.future;
    return super.getDiverById(id);
  }
}

/// The tag management switch (issue #998) can be flipped before the diver's
/// settings row has loaded. The load then replaces the whole state, so a
/// setter that did not wait for it would lose the diver's choice.
void main() {
  late ProviderContainer container;
  late Completer<void> gate;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    gate = Completer<void>();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverRepositoryProvider.overrideWithValue(_GatedDiverRepository(gate)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('a change made before the initial load survives that load', () async {
    final notifier = container.read(settingsProvider.notifier);
    expect(container.read(settingsProvider).autoTagImports, isTrue);

    final pending = notifier.setAutoTagImports(false);
    // The stored row says on; releasing the load now is what used to
    // overwrite the diver's off.
    gate.complete();
    await pending;

    expect(container.read(settingsProvider).autoTagImports, isFalse);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.autoTagImports, isFalse);
  });

  test('a change after the load applies and persists directly', () async {
    gate.complete();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;

    await notifier.setAutoTagImports(false);

    expect(container.read(settingsProvider).autoTagImports, isFalse);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.autoTagImports, isFalse);
  });
}
