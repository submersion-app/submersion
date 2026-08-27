import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/test_database.dart';

Diver _makeDiver({String name = 'Default', bool isDefault = true}) {
  final now = DateTime.now();
  return Diver(
    id: '',
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

TankPresetEntity _makePreset({String name = 'Custom Tank', String? diverId}) {
  return TankPresetEntity.create(
    id: '',
    name: name,
    displayName: name,
    volumeLiters: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    diverId: diverId,
  );
}

/// Fake repository whose `getAllPresets` throws, to drive the error path.
/// `watchTankPresetsChanges()` is inherited from the real repository and works
/// against the in-memory test DB set up in [setUp].
class _ThrowingTankPresetRepository extends TankPresetRepository {
  @override
  Future<List<TankPresetEntity>> getAllPresets({String? diverId}) async {
    throw Exception('boom');
  }
}

void main() {
  late SharedPreferences prefs;
  late DiverRepository diverRepo;
  late TankPresetRepository presetRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    diverRepo = DiverRepository();
    presetRepo = TankPresetRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and marks it current so diver-scoped custom
  /// presets resolve. Returns the diver id.
  Future<String> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(_makeDiver());
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver.id;
  }

  group('tankPresetsProvider (base FutureProvider)', () {
    test(
      'auto-refreshes after a write to the tank_presets table (sync scenario)',
      () async {
        final diverId = await seedCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);

        // An active listener keeps the provider (and its table-change
        // subscription) alive, mirroring a widget watching the preset list.
        final sub = container.listen(tankPresetsProvider, (_, _) {});
        addTearDown(sub.close);

        // Initial resolve: only built-in presets, no custom rows yet.
        final initial = await container.read(tankPresetsProvider.future);
        expect(initial.map((p) => p.name), isNot(contains('Synced Tank')));

        // A sync applies a remote custom preset straight to the DB (no notifier
        // mutation). The watchTankPresetsChanges tick must invalidate the
        // provider so the new row appears.
        await presetRepo.createPreset(
          _makePreset(name: 'Synced Tank', diverId: diverId),
        );

        // Poll until the tick -> invalidateSelf -> rebuild settles.
        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            tankPresetsProvider.future,
          )).map((p) => p.name).toList();
          if (names.contains('Synced Tank')) break;
        }

        expect(
          names,
          contains('Synced Tank'),
          reason:
              'tankPresetsProvider should auto-refresh after the table write '
              'without any manual invalidation',
        );
      },
    );
  });

  group('tankPresetListNotifierProvider '
      '(TankPresetListNotifier._silentReloadPresets)', () {
    test('silently reloads the list when a preset is written directly to the '
        'DB (sync scenario)', () async {
      final diverId = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(tankPresetListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      // Wait for the initial load to settle (built-in presets only).
      while (container.read(tankPresetListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      final initialNames =
          (container.read(tankPresetListNotifierProvider).value ?? [])
              .map((p) => p.name)
              .toList();
      expect(initialNames, isNot(contains('Synced Tank')));

      // A sync applies a remote custom preset straight to the DB (no notifier
      // mutation call). The watchTankPresetsChanges tick must silently reload
      // via _silentReloadPresets so the list reflects the new row.
      await presetRepo.createPreset(
        _makePreset(name: 'Synced Tank', diverId: diverId),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(tankPresetListNotifierProvider).value ?? [])
            .map((p) => p.name)
            .toList();
        if (names.contains('Synced Tank')) break;
      }

      expect(
        names,
        contains('Synced Tank'),
        reason:
            'TankPresetListNotifier should silently reload after a direct DB '
            'write without any manual refresh() call',
      );
    });

    test('reports AsyncError when the initial load throws', () async {
      await seedCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tankPresetRepositoryProvider.overrideWithValue(
            _ThrowingTankPresetRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(tankPresetListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      // The initial load already fails; poll until the error state settles.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(tankPresetListNotifierProvider).hasError) break;
      }

      expect(container.read(tankPresetListNotifierProvider).hasError, isTrue);
    });
  });
}
