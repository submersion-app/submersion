import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

void main() {
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
        SetupStepId.backupSync,
        SetupStepId.finish,
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
      expect(computeSteps(sync).last, SetupStepId.syncConnect);

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
        SetupStepId.backupSync,
        SetupStepId.finish,
      ]);
    });
  });

  group('SetupWizardDraft', () {
    test('applyUnitPreset imperial sets the six core units', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);
      final imperial = draft.applyingUnitPreset(UnitPreset.imperial);
      expect(imperial.settings.depthUnit, DepthUnit.feet);
      expect(imperial.settings.temperatureUnit, TemperatureUnit.fahrenheit);
      expect(imperial.settings.pressureUnit, PressureUnit.psi);
      expect(imperial.settings.volumeUnit, VolumeUnit.cubicFeet);
      expect(imperial.settings.weightUnit, WeightUnit.pounds);
      expect(imperial.settings.altitudeUnit, AltitudeUnit.feet);
      // sacUnit untouched by preset
      expect(imperial.settings.sacUnit, const AppSettings().sacUnit);
      // and back to metric
      final metric = imperial.applyingUnitPreset(UnitPreset.metric);
      expect(metric.settings.unitPreset, UnitPreset.metric);
    });
  });
}
