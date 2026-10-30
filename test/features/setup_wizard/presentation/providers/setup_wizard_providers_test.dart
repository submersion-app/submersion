import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';

void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts undecided in first-run mode, seeded from defaults', () {
    final container = makeContainer();
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.undecided);
    expect(draft.settings, const AppSettings());
  });

  test('mutators update the draft', () {
    final container = makeContainer();
    final notifier = container.read(
      setupWizardProvider(SetupWizardMode.firstRun).notifier,
    );
    notifier.choosePath(SetupPath.fresh);
    notifier.setName('  Eric  ');
    notifier.applyUnitPreset(UnitPreset.imperial);

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.fresh);
    expect(draft.name, 'Eric');
    expect(draft.settings.unitPreset, UnitPreset.imperial);
    expect(computeSteps(draft), containsAll(kSetUpWizardSteps));
  });

  test('requireProfile adds the Profile step to the existing-data path', () {
    final container = makeContainer();
    final notifier = container.read(
      setupWizardProvider(SetupWizardMode.firstRun).notifier,
    );
    notifier
      ..choosePath(SetupPath.existingData)
      ..chooseSource(ExistingDataSource.cloudSync)
      ..requireProfile();
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.needsProfile, isTrue);
    expect(computeSteps(draft), contains(SetupStepId.profile));
  });

  test('requestSkip trims the fresh path', () {
    final container = makeContainer();
    final notifier = container.read(
      setupWizardProvider(SetupWizardMode.firstRun).notifier,
    );
    notifier.requestSkip();
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.fresh);
    expect(draft.skipRequested, isTrue);
    expect(computeSteps(draft), [
      SetupStepId.welcomeFork,
      SetupStepId.profile,
      SetupStepId.finish,
    ]);
  });
}
