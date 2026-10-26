import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether the wizard runs at first launch or from Settings.
enum SetupWizardMode { firstRun, settings }

/// Which top-level branch the user chose on the fork step.
enum SetupPath { undecided, fresh, existingData }

/// Which existing-data source the user chose.
enum ExistingDataSource { none, restoreBackup, cloudSync, openFolder }

/// Identity of every wizard step; the shell maps these to widgets.
enum SetupStepId {
  welcomeFork,
  profile,
  units,

  /// The four Set up this device steps (spec 6.6), shared with Settings.
  setUpAccount,
  setUpSync,
  setUpBackups,
  setUpPhotos,
  finish,
  existingChoice,
  restore,
  openFolder,
}

/// The four Set up this device steps, in order.
const kSetUpWizardSteps = [
  SetupStepId.setUpAccount,
  SetupStepId.setUpSync,
  SetupStepId.setUpBackups,
  SetupStepId.setUpPhotos,
];

/// Immutable wizard draft: the profile and units, which Finish applies.
/// The Set up this device steps write on their own buttons (spec 6.6).
class SetupWizardDraft {
  final SetupWizardMode mode;
  final SetupPath path;
  final ExistingDataSource source;
  final bool skipRequested;
  final String name;
  final AppSettings settings;

  /// Finish found no diver and no name to create one with: the Profile
  /// step is asked for before Finish.
  final bool needsProfile;

  const SetupWizardDraft({
    required this.mode,
    this.path = SetupPath.undecided,
    this.source = ExistingDataSource.none,
    this.skipRequested = false,
    this.name = '',
    this.settings = const AppSettings(),
    this.needsProfile = false,
  });

  SetupWizardDraft copyWith({
    SetupPath? path,
    ExistingDataSource? source,
    bool? skipRequested,
    String? name,
    AppSettings? settings,
    bool? needsProfile,
  }) {
    return SetupWizardDraft(
      mode: mode,
      path: path ?? this.path,
      source: source ?? this.source,
      skipRequested: skipRequested ?? this.skipRequested,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      needsProfile: needsProfile ?? this.needsProfile,
    );
  }

  /// Returns a copy with the seven core units set to [preset].
  /// [UnitPreset.custom] returns this draft unchanged.
  SetupWizardDraft applyingUnitPreset(UnitPreset preset) {
    switch (preset) {
      case UnitPreset.metric:
        return copyWith(
          settings: settings.copyWith(
            depthUnit: DepthUnit.meters,
            temperatureUnit: TemperatureUnit.celsius,
            pressureUnit: PressureUnit.bar,
            volumeUnit: VolumeUnit.liters,
            weightUnit: WeightUnit.kilograms,
            altitudeUnit: AltitudeUnit.meters,
            distanceUnit: DistanceUnit.kilometers,
          ),
        );
      case UnitPreset.imperial:
        return copyWith(
          settings: settings.copyWith(
            depthUnit: DepthUnit.feet,
            temperatureUnit: TemperatureUnit.fahrenheit,
            pressureUnit: PressureUnit.psi,
            volumeUnit: VolumeUnit.cubicFeet,
            weightUnit: WeightUnit.pounds,
            altitudeUnit: AltitudeUnit.feet,
            distanceUnit: DistanceUnit.miles,
          ),
        );
      case UnitPreset.custom:
        return this;
    }
  }
}

/// Computes the ordered step list for the current draft state.
List<SetupStepId> computeSteps(SetupWizardDraft draft) {
  if (draft.mode == SetupWizardMode.settings) {
    return const [SetupStepId.units, ...kSetUpWizardSteps, SetupStepId.finish];
  }
  switch (draft.path) {
    case SetupPath.undecided:
      return const [SetupStepId.welcomeFork];
    case SetupPath.fresh:
      if (draft.skipRequested) {
        return const [
          SetupStepId.welcomeFork,
          SetupStepId.profile,
          SetupStepId.finish,
        ];
      }
      return const [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.units,
        ...kSetUpWizardSteps,
        SetupStepId.finish,
      ];
    case SetupPath.existingData:
      final steps = [SetupStepId.welcomeFork, SetupStepId.existingChoice];
      switch (draft.source) {
        case ExistingDataSource.none:
          break;
        case ExistingDataSource.restoreBackup:
          steps.add(SetupStepId.restore);
        case ExistingDataSource.cloudSync:
          steps.addAll([
            ...kSetUpWizardSteps,
            if (draft.needsProfile) SetupStepId.profile,
            SetupStepId.finish,
          ]);
        case ExistingDataSource.openFolder:
          steps.add(SetupStepId.openFolder);
      }
      return steps;
  }
}
