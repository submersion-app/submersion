import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/data/setup_apply_service.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'applyFirstRun creates default diver, seeds settings, sets current',
    () async {
      final container = makeContainer();
      final service = container.read(setupApplyServiceProvider);

      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
        name: 'Eric',
        backupEnabled: true,
        backupFrequency: BackupFrequency.daily,
      );
      final imperialDraft = draft.applyingUnitPreset(UnitPreset.imperial);

      await service.applyFirstRun(imperialDraft);

      final divers = await DiverRepository().getAllDivers();
      expect(divers, hasLength(1));
      expect(divers.single.name, 'Eric');
      expect(divers.single.isDefault, isTrue);

      // Settings row was seeded with the draft BEFORE the diver switch.
      final stored = await DiverSettingsRepository().getSettingsForDiver(
        divers.single.id,
      );
      expect(stored, isNotNull);
      expect(stored!.depthUnit, DepthUnit.feet);
      expect(stored.pressureUnit, PressureUnit.psi);
      expect(stored.weightUnit, WeightUnit.pounds);
      expect(stored.distanceUnit, DistanceUnit.miles);

      // Current diver persisted to prefs.
      expect(prefs.getString(currentDiverIdKey), divers.single.id);

      // Backup schedule applied.
      final backup = container.read(backupSettingsProvider);
      expect(backup.enabled, isTrue);
      expect(backup.frequency, BackupFrequency.daily);
    },
  );

  // Issue #2298. On a fresh database the app is already running with a live
  // SettingsNotifier and CurrentDiverIdNotifier. Creating the wizard's diver
  // ticks the divers table, the id notifier self-repairs to that new default
  // diver, and the settings notifier reloads the row createDiver seeded with
  // the metric defaults. The wizard's own setCurrentDiver then names the same
  // id, so no second reload ran: the notifier kept metric in memory and the
  // next settings write (from anywhere, an import included) persisted it.
  test('applyFirstRun leaves a live settings notifier on the draft units, '
      'and a later settings write keeps them', () async {
    final container = makeContainer();
    container.listen(currentDiverIdProvider, (_, _) {});
    container.listen(settingsProvider, (_, _) {});
    await container.read(settingsProvider.notifier).initialLoad;

    const draft = SetupWizardDraft(
      mode: SetupWizardMode.firstRun,
      path: SetupPath.fresh,
      name: 'Eric',
    );
    await container
        .read(setupApplyServiceProvider)
        .applyFirstRun(draft.applyingUnitPreset(UnitPreset.imperial));
    await pumpEventQueue(times: 50);

    final diverId = container.read(currentDiverIdProvider)!;
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    expect(container.read(settingsProvider).pressureUnit, PressureUnit.psi);

    // Any setter writes the whole in-memory settings back to the row.
    await container.read(settingsProvider.notifier).setAutoTagImports(false);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.pressureUnit, PressureUnit.psi);
  });

  test(
    'applyFirstRun with empty name throws ArgumentError and writes nothing',
    () async {
      final container = makeContainer();
      final service = container.read(setupApplyServiceProvider);
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);

      await expectLater(service.applyFirstRun(draft), throwsArgumentError);
      expect(await DiverRepository().getAllDivers(), isEmpty);
    },
  );

  test(
    'applySettingsMode updates the current diver via existing setters',
    () async {
      final container = makeContainer();

      // Seed a diver + make it current, mirroring a real re-entry session.
      final repo = DiverRepository();
      final now = DateTime.now();
      final diver = await repo.createDiver(
        Diver(
          id: '',
          name: 'Existing',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(diver.id);
      // Let the SettingsNotifier finish its reload before applying, mirroring
      // a settled re-entry session (bounded poll; see plan Task 5 note).
      container.read(settingsProvider.notifier);
      var waited = 0;
      while (waited < 1000) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        waited += 20;
        // A loaded notifier persists writes; probe via the repository.
        final probe = await DiverSettingsRepository().getSettingsForDiver(
          diver.id,
        );
        if (probe != null) break;
      }

      final service = container.read(setupApplyServiceProvider);
      const base = SetupWizardDraft(mode: SetupWizardMode.settings);
      final draft = base.applyingUnitPreset(UnitPreset.imperial);
      await service.applySettingsMode(draft);

      expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
      final stored = await DiverSettingsRepository().getSettingsForDiver(
        diver.id,
      );
      expect(stored!.depthUnit, DepthUnit.feet);
      expect(stored.volumeUnit, VolumeUnit.cubicFeet);
      expect(stored.distanceUnit, DistanceUnit.miles);
    },
  );

  test(
    'settings-mode draft seeds live backup state; Finish preserves it',
    () async {
      // A backup schedule is already enabled before the wizard opens.
      SharedPreferences.setMockInitialValues({
        'backup_enabled': true,
        'backup_frequency': 'daily',
      });
      final seededPrefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(seededPrefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).initialLoad;

      // The re-entry draft must mirror the live schedule, not defaults.
      final draft = container.read(
        setupWizardProvider(SetupWizardMode.settings),
      );
      expect(draft.backupEnabled, isTrue);
      expect(draft.backupFrequency, BackupFrequency.daily);

      // Applying an untouched settings-mode draft must not disable backups
      // (regression: seeding defaults here silently turned them off).
      await container.read(setupApplyServiceProvider).applySettingsMode(draft);
      expect(container.read(backupSettingsProvider).enabled, isTrue);
      expect(
        container.read(backupSettingsProvider).frequency,
        BackupFrequency.daily,
      );
    },
  );
}
