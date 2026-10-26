import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The loader `diveImportServiceProvider` hands to `DiveImportService`
/// (issue #386): it turns the diver's settings into the preset to fill
/// downloaded cylinders with, or null when the diver has not opted in.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<TankPresetEntity?> load(
    AppSettings settings, {
    String? diverId,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(container.dispose);
    final probe = FutureProvider<TankPresetEntity?>(
      (ref) => loadDefaultTankPresetForDownloads(ref),
    );
    return container.read(probe.future);
  }

  test('yields nothing while the toggle is off', () async {
    final preset = await load(
      const AppSettings(
        applyDefaultTankToImports: false,
        defaultTankPreset: 'al80',
      ),
    );

    expect(preset, isNull);
  });

  test(
    'resolves the configured built-in preset when the toggle is on',
    () async {
      final preset = await load(
        const AppSettings(
          applyDefaultTankToImports: true,
          defaultTankPreset: 'al80',
        ),
      );

      expect(preset?.name, 'al80');
      expect(preset?.volumeLiters, 11.1);
    },
  );

  test('ignoreImportOptIn resolves the preset while the toggle is off '
      '(issue #3668)', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(
              applyDefaultTankToImports: false,
              defaultTankPreset: 'al80',
            ),
          ),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final probe = FutureProvider<TankPresetEntity?>(
      (ref) => loadDefaultTankPresetForDownloads(ref, ignoreImportOptIn: true),
    );

    expect((await container.read(probe.future))?.name, 'al80');
  });

  test('yields nothing for a preset that no longer exists', () async {
    final preset = await load(
      const AppSettings(
        applyDefaultTankToImports: true,
        defaultTankPreset: 'deleted-custom-tank',
      ),
    );

    expect(preset, isNull);
  });

  group('for a diver other than the active one (issue #2050)', () {
    Future<TankPresetEntity?> loadFor(
      String diverId, {
      String? activeDiverId,
    }) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => activeDiverId,
          ),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(applyDefaultTankToImports: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final probe = FutureProvider<TankPresetEntity?>(
        (ref) => loadDefaultTankPresetForDownloads(ref, diverId: diverId),
      );
      return container.read(probe.future);
    }

    Future<void> addDiver(String id) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    test("uses that diver's preset, not the active diver's", () async {
      await addDiver('mitchell');
      await DiverSettingsRepository().createSettingsForDiver(
        'mitchell',
        settings: const AppSettings(
          applyDefaultTankToImports: true,
          defaultTankPreset: 'al80',
        ),
      );

      final preset = await loadFor('mitchell');

      expect(preset?.name, 'al80');
    });

    test(
      'an unreadable settings row means no preset, not a failed import',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            diverSettingsRepositoryProvider.overrideWithValue(
              _ThrowingSettingsRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final probe = FutureProvider<TankPresetEntity?>(
          (ref) => loadDefaultTankPresetForDownloads(ref, diverId: 'mitchell'),
        );

        expect(await container.read(probe.future), isNull);
      },
    );

    test('a diver with no saved settings gets the default (off)', () async {
      await addDiver('mitchell');

      expect(await loadFor('mitchell'), isNull);
    });

    test("resolves that diver's own custom preset, not the active "
        "diver's", () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await addDiver('bill');
      await addDiver('mitchell');
      for (final (diverId, presetId, volume) in [
        ('bill', 'dubbel_7', 14.0),
        ('mitchell', 'dubbel_7_m1', 7.0),
      ]) {
        await db
            .into(db.tankPresets)
            .insert(
              TankPresetsCompanion(
                id: Value(presetId),
                diverId: Value(diverId),
                name: const Value('dubbel_7'),
                displayName: const Value('Dubbel 7'),
                volumeLiters: Value(volume),
                workingPressureBar: const Value(232),
                material: const Value('steel'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      await DiverSettingsRepository().createSettingsForDiver(
        'mitchell',
        settings: const AppSettings(
          applyDefaultTankToImports: true,
          defaultTankPreset: 'dubbel_7',
        ),
      );

      final preset = await loadFor('mitchell', activeDiverId: 'bill');

      expect(preset?.volumeLiters, 7.0);
    });
  });

  test('resolves the active diver\'s own custom preset (#3343)', () async {
    // A copied profile holds a preset of the same name: each diver's
    // default names their own cylinder, never the other profile's.
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (diverId, presetId, volume) in [
      ('diver-a', 'dubbel_7', 14.0),
      ('diver-b', 'dubbel_7_1a2b3c4d', 7.0),
    ]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(diverId),
              name: Value(diverId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.tankPresets)
          .insert(
            TankPresetsCompanion(
              id: Value(presetId),
              diverId: Value(diverId),
              name: const Value('dubbel_7'),
              displayName: const Value('Dubbel 7'),
              volumeLiters: Value(volume),
              workingPressureBar: const Value(232),
              material: const Value('steel'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    const settings = AppSettings(
      applyDefaultTankToImports: true,
      defaultTankPreset: 'dubbel_7',
    );

    final forA = await load(settings, diverId: 'diver-a');
    final forB = await load(settings, diverId: 'diver-b');

    expect(forA?.volumeLiters, 14.0);
    expect(forB?.volumeLiters, 7.0);
  });

  group('end to end through diveImportServiceProvider', () {
    // A transmitter-equipped back gas: pressures, no size, as every dive
    // computer reports it.
    DownloadedDive downloadedDive() => DownloadedDive(
      fingerprint: 'fp-e2e',
      startTime: DateTime(2026, 4, 1, 10, 0),
      durationSeconds: 2700,
      maxDepth: 18.0,
      profile: const [],
      tanks: const [
        DownloadedTank(
          index: 0,
          o2Percent: 21.0,
          startPressure: 200.0,
          endPressure: 60.0,
          role: 'backGas',
        ),
      ],
      events: const [],
    );

    Future<double?> importedVolume(AppSettings settings) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: const Value('computer-1'),
              name: const Value('Perdix'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
        ],
      );
      addTearDown(container.dispose);

      final diveId = await container
          .read(diveImportServiceProvider)
          .importSingleDiveAsNew(downloadedDive(), computerId: 'computer-1');

      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).getSingle();
      return tank.volume;
    }

    test('a download gains the default cylinder size when opted in', () async {
      final volume = await importedVolume(
        const AppSettings(
          applyDefaultTankToImports: true,
          defaultTankPreset: 'al80',
        ),
      );

      expect(volume, 11.1);
    });

    test('a download stays sizeless while the toggle is off', () async {
      final volume = await importedVolume(
        const AppSettings(
          applyDefaultTankToImports: false,
          defaultTankPreset: 'al80',
        ),
      );

      expect(volume, isNull);
    });
  });
}

class _ThrowingSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings?> getSettingsForDiver(String diverId) async =>
      throw StateError('database is locked');
}
