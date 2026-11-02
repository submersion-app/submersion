import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

void main() {
  group('offersNoLibrary', () {
    test('the browser connect step offers it on the existing-data path', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        browser: true,
      );
      expect(offersNoLibrary(draft, SetupStepId.setUpAccount), isTrue);
      expect(offersNoLibrary(draft, SetupStepId.setUpSync), isTrue);
    });

    test('once the path is fresh the connect step keeps Not now', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
        browser: true,
      );
      expect(offersNoLibrary(draft, SetupStepId.setUpAccount), isFalse);
      expect(offersNoLibrary(draft, SetupStepId.setUpSync), isFalse);
    });

    test('natively only the sync step offers it', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
      );
      expect(offersNoLibrary(draft, SetupStepId.setUpAccount), isFalse);
      expect(offersNoLibrary(draft, SetupStepId.setUpSync), isTrue);
    });
  });

  group('computeSteps', () {
    test('first run starts with fork only while path undecided', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);
      expect(computeSteps(draft), [SetupStepId.welcomeFork]);
    });

    test('fresh path shows full first-run flow', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
      );
      expect(computeSteps(draft), [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.units,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ]);
      expect(kSetUpWizardSteps, [
        SetupStepId.setUpAccount,
        SetupStepId.setUpSync,
        SetupStepId.setUpBackups,
        SetupStepId.setUpPhotos,
      ]);
    });

    test('skip setup collapses fresh path to profile then finish', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
        skipRequested: true,
      );
      expect(computeSteps(draft), [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.finish,
      ]);
    });

    test('existing-data path shows choice, then source step', () {
      const undecided = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
      );
      expect(computeSteps(undecided), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
      ]);

      const restore = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.restoreBackup,
      );
      expect(computeSteps(restore), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
        SetupStepId.restore,
      ]);

      const sync = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.cloudSync,
      );
      expect(computeSteps(sync), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ]);

      // A downloaded library with no diver: Finish asks for a name.
      final syncNeedsName = sync.copyWith(needsProfile: true);
      expect(computeSteps(syncNeedsName), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
        ...kSetUpWizardSteps,
        SetupStepId.profile,
        SetupStepId.finish,
      ]);

      const folder = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.openFolder,
      );
      expect(computeSteps(folder).last, SetupStepId.openFolder);
    });

    test('settings mode hides fork and profile', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.settings);
      expect(computeSteps(draft), [
        SetupStepId.units,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ]);
    });

    test('a fresh path that needs a name already asks for it', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
        needsProfile: true,
      );
      expect(
        computeSteps(draft).where((s) => s == SetupStepId.profile).length,
        1,
      );
    });
  });

  group('SetupWizardDraft', () {
    test('applyUnitPreset metric sets distance back to kilometres', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        settings: AppSettings(distanceUnit: DistanceUnit.miles),
      );
      final metric = draft.applyingUnitPreset(UnitPreset.metric);
      expect(metric.settings.distanceUnit, DistanceUnit.kilometers);
    });

    test('applyUnitPreset imperial sets the seven core units', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);
      final imperial = draft.applyingUnitPreset(UnitPreset.imperial);
      expect(imperial.settings.depthUnit, DepthUnit.feet);
      expect(imperial.settings.temperatureUnit, TemperatureUnit.fahrenheit);
      expect(imperial.settings.pressureUnit, PressureUnit.psi);
      expect(imperial.settings.volumeUnit, VolumeUnit.cubicFeet);
      expect(imperial.settings.weightUnit, WeightUnit.pounds);
      expect(imperial.settings.altitudeUnit, AltitudeUnit.feet);
      expect(imperial.settings.distanceUnit, DistanceUnit.miles);
      // gasConsumptionDisplay untouched by preset
      expect(
        imperial.settings.gasConsumptionDisplay,
        const AppSettings().gasConsumptionDisplay,
      );
      // and back to metric
      final metric = imperial.applyingUnitPreset(UnitPreset.metric);
      expect(metric.settings.unitPreset, UnitPreset.metric);
    });
  });

  group('computeSteps in a browser (#4121)', () {
    test('a first run opens on the connect step', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        browser: true,
        path: SetupPath.existingData,
        source: ExistingDataSource.cloudSync,
      );
      expect(computeSteps(draft), [...kSetUpWizardSteps, SetupStepId.finish]);
    });

    test('continue without a sync store runs profile, units, the steps '
        'and finish, with no fork to go back to', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        browser: true,
        path: SetupPath.fresh,
      );
      expect(computeSteps(draft), [
        SetupStepId.profile,
        SetupStepId.units,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ]);
    });

    test('a draft with no path yet still opens on the connect step', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        browser: true,
      );
      expect(computeSteps(draft), [...kSetUpWizardSteps, SetupStepId.finish]);
    });

    test('the settings assistant is unchanged', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.settings,
        browser: true,
      );
      expect(computeSteps(draft), [
        SetupStepId.units,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ]);
    });
  });
}
