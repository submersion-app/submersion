import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
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

/// Every setter waits for the diver's settings to load before it applies its
/// change (issue #4449). The load replaces the whole state when it lands, so
/// a change applied to the defaults before then was saved to no row and then
/// lost. A change worked out from the current settings (a set gaining an
/// entry, say) must also be worked out from the loaded ones, or it drops what
/// the diver had stored.
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
    // The stored row differs from the defaults in the fields the computed
    // setters below build on.
    final repository = DiverSettingsRepository();
    final created = await repository.getOrCreateSettingsForDiver(diverId);
    await repository.updateSettingsForDiver(
      diverId,
      created.copyWith(
        hiddenTankPresetIds: const {'hp100'},
        serviceReminderDays: const [7],
      ),
      previous: created,
    );
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

  test('changes made before the initial load survive that load', () async {
    final notifier = container.read(settingsProvider.notifier);

    final pending = Future.wait([
      notifier.setDepthUnit(DepthUnit.feet),
      notifier.setGfLow(35),
      notifier.setTankPresetHidden('hp80', true),
      notifier.toggleReminderDay(30),
      notifier.setColdWaterThresholdC(15),
    ]);
    // Nothing applies while the load is out: it would be overwritten.
    expect(container.read(settingsProvider).depthUnit, DepthUnit.meters);
    gate.complete();
    await pending;

    final settings = container.read(settingsProvider);
    expect(settings.depthUnit, DepthUnit.feet);
    expect(settings.gfLow, 35);
    expect(settings.hiddenTankPresetIds, {'hp100', 'hp80'});
    expect(settings.serviceReminderDays, [30, 7]);
    expect(settings.coldWaterThresholdC, 15);

    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.gfLow, 35);
    expect(stored.hiddenTankPresetIds, {'hp100', 'hp80'});
    expect(stored.serviceReminderDays, [30, 7]);
    expect(stored.coldWaterThresholdC, 15);
  });

  test('a change made just after the load lands is not undone by one queued '
      'before it', () async {
    final notifier = container.read(settingsProvider.notifier);
    final queued = notifier.setDepthUnit(DepthUnit.feet);
    Future<void>? later;
    // The load assigns state when it lands, then finishes its own writes.
    // A change made in between is the diver's latest and must win.
    final sub = container.listen(settingsProvider, (_, _) {
      later ??= Future.microtask(() => notifier.setDepthUnit(DepthUnit.meters));
    });
    addTearDown(sub.close);
    gate.complete();
    await queued;
    await later;

    expect(container.read(settingsProvider).depthUnit, DepthUnit.meters);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.depthUnit, DepthUnit.meters);
  });

  test('once the load has landed a change applies before the setter '
      'returns', () async {
    gate.complete();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;

    final saving = notifier.setDepthUnit(DepthUnit.feet);
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    await saving;

    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.depthUnit, DepthUnit.feet);
  });
}
