import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
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

  Future<TankPresetEntity?> load(AppSettings settings) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
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

  test('yields nothing for a preset that no longer exists', () async {
    final preset = await load(
      const AppSettings(
        applyDefaultTankToImports: true,
        defaultTankPreset: 'deleted-custom-tank',
      ),
    );

    expect(preset, isNull);
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
