import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
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
      );
      final imperialDraft = draft.applyingUnitPreset(UnitPreset.imperial);

      expect(await service.applyFirstRun(imperialDraft), FirstRunApply.created);

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
    },
  );

  // Issue #3482 phase 7 (spec 6.6): Finish creates the diver only when the
  // device has none once the steps are done, and the steps own backups.
  group('Finish after the set up steps', () {
    const base = SetupWizardDraft(
      mode: SetupWizardMode.firstRun,
      path: SetupPath.fresh,
      name: 'Eric',
    );

    Future<void> pinCopyTo(String id) async {
      final backup = BackupPreferences(prefs);
      await backup.setEnabled(true);
      await backup.setCloudBackupEnabled(true);
      await backup.setCopyDestination(accountId: id, kind: AccountKind.dropbox);
    }

    test(
      'creates the diver when the device has none after a download',
      () async {
        final container = makeContainer();

        final result = await container
            .read(setupApplyServiceProvider)
            .applyFirstRun(base);

        expect(result, FirstRunApply.created);
        expect(await DiverRepository().getAllDivers(), hasLength(1));
      },
    );

    test("keeps the library's divers", () async {
      final now = DateTime(2026, 10, 25);
      await DiverRepository().createDiver(
        Diver(
          id: '',
          name: 'Library diver',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final container = makeContainer();

      final result = await container
          .read(setupApplyServiceProvider)
          .applyFirstRun(base);

      expect(result, FirstRunApply.keptExisting);
      final divers = await DiverRepository().getAllDivers();
      expect(divers.map((d) => d.name), ['Library diver']);
    });

    test('asks for a name when there is no diver and no name', () async {
      final container = makeContainer();

      final result = await container
          .read(setupApplyServiceProvider)
          .applyFirstRun(base.copyWith(name: ''));

      expect(result, FirstRunApply.needsName);
      expect(await DiverRepository().getAllDivers(), isEmpty);
    });

    test('leaves the backups the steps chose as they are', () async {
      await pinCopyTo('acct-b');
      final container = makeContainer();

      await container.read(setupApplyServiceProvider).applyFirstRun(base);

      final s = BackupPreferences(prefs).getSettings();
      expect(s.enabled, isTrue);
      expect(s.cloudBackupEnabled, isTrue);
      expect(s.copyAccountId, 'acct-b');
    });
  });

  // Issue #3111. The app language defaults to the device's, but place names
  // defaulted to English, so a German install stored "Germany" and "Spain".
  group('applyFirstRun place name language', () {
    const draft = SetupWizardDraft(
      mode: SetupWizardMode.firstRun,
      path: SetupPath.fresh,
      name: 'Eric',
    );

    Future<String> storedPlaceNameLanguage() async {
      final diver = (await DiverRepository().getAllDivers()).single;
      final stored = await DiverSettingsRepository().getSettingsForDiver(
        diver.id,
      );
      return stored!.placeNameLanguage;
    }

    test('follows the first supported device language', () async {
      final service = makeContainer().read(setupApplyServiceProvider);

      await service.applyFirstRun(
        draft,
        deviceLanguageCodes: const ['pl', 'de'],
      );

      expect(await storedPlaceNameLanguage(), 'de');
    });

    test('stays English when no device language is supported', () async {
      final service = makeContainer().read(setupApplyServiceProvider);

      await service.applyFirstRun(draft, deviceLanguageCodes: const ['pl']);

      expect(await storedPlaceNameLanguage(), 'en');
    });
  });

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

  test('settings-mode Finish leaves backups as they are', () async {
    SharedPreferences.setMockInitialValues({
      'backup_enabled': true,
      'backup_frequency': 'daily',
      'backup_cloud_enabled': true,
      'backup_copy_account_id': 'acct-b',
      'backup_copy_account_kind': AccountKind.dropbox.name,
    });
    final seededPrefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(seededPrefs)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).initialLoad;

    final draft = container.read(setupWizardProvider(SetupWizardMode.settings));
    await container.read(setupApplyServiceProvider).applySettingsMode(draft);

    final backup = container.read(backupSettingsProvider);
    expect(backup.enabled, isTrue);
    expect(backup.frequency, BackupFrequency.daily);
    expect(backup.cloudBackupEnabled, isTrue);
    expect(backup.copyAccountId, 'acct-b');
  });
}
