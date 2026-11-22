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

  /// The species identification model, after the Photos step, on a device
  /// that can run it and has none (issue #4881). Wizard only: not one of
  /// the Set up this device steps.
  speciesModel,
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

  /// The wizard runs in a browser (issue #4121): the first run opens on the
  /// connect step, with no welcome fork or existing-data choice before it.
  final bool browser;

  /// The species model step is offered (issue #4881). Set once, from facts
  /// read when the wizard opens, and never cleared: starting the download
  /// turns the live offer off, and the step must stay where the diver left
  /// it.
  final bool speciesModelOffered;

  const SetupWizardDraft({
    required this.mode,
    this.path = SetupPath.undecided,
    this.source = ExistingDataSource.none,
    this.skipRequested = false,
    this.name = '',
    this.settings = const AppSettings(),
    this.needsProfile = false,
    this.browser = false,
    this.speciesModelOffered = false,
  });

  SetupWizardDraft copyWith({
    SetupPath? path,
    ExistingDataSource? source,
    bool? skipRequested,
    String? name,
    AppSettings? settings,
    bool? needsProfile,
    bool? speciesModelOffered,
  }) {
    return SetupWizardDraft(
      mode: mode,
      browser: browser,
      path: path ?? this.path,
      source: source ?? this.source,
      skipRequested: skipRequested ?? this.skipRequested,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      needsProfile: needsProfile ?? this.needsProfile,
      speciesModelOffered: speciesModelOffered ?? this.speciesModelOffered,
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

/// Whether a shared step offers to start without a sync store: natively the
/// sync step on the existing-data path; in a browser the connect step it
/// opens on as well (issue #4121). Once the user took the offer the path is
/// fresh and the step keeps its native Not now, or the offer would send
/// them round the profile steps again.
bool offersNoLibrary(SetupWizardDraft draft, SetupStepId id) {
  if (draft.path != SetupPath.existingData) return false;
  return id == SetupStepId.setUpSync ||
      (draft.browser && id == SetupStepId.setUpAccount);
}

/// The two Set up this device steps a browser keeps (issue #4121): it has
/// no files to back up on a schedule and no photo library to sync.
const kBrowserSetUpWizardSteps = [
  SetupStepId.setUpAccount,
  SetupStepId.setUpSync,
];

/// Whether an offer of the species model that arrives now may still add its
/// step (issue #4881): only while the diver has not passed the Photos step,
/// so the step is never inserted behind them. A list with no Photos step yet
/// (the path is still undecided) takes the offer for later.
bool speciesModelOfferFits(List<SetupStepId> steps, int currentIndex) {
  final photos = steps.indexOf(SetupStepId.setUpPhotos);
  return photos < 0 || currentIndex <= photos;
}

/// Computes the ordered step list for the current draft state.
List<SetupStepId> computeSteps(SetupWizardDraft draft) =>
    _withSpeciesModel(draft, _trimmedForBrowser(draft));

/// The species model step right after the Photos step, when it is offered
/// (issue #4881). A list with no Photos step (skip, restore, open folder, a
/// browser) never gets it.
List<SetupStepId> _withSpeciesModel(
  SetupWizardDraft draft,
  List<SetupStepId> steps,
) {
  if (!draft.speciesModelOffered) return steps;
  final photos = steps.indexOf(SetupStepId.setUpPhotos);
  if (photos < 0) return steps;
  return [
    ...steps.take(photos + 1),
    SetupStepId.speciesModel,
    ...steps.skip(photos + 1),
  ];
}

List<SetupStepId> _trimmedForBrowser(SetupWizardDraft draft) {
  final steps = _stepsForPath(draft);
  if (!draft.browser) return steps;
  // A browser drops the backups and photos steps in every mode, and its
  // first run has no welcome fork and no existing-data choice before it: it
  // opens on the connect step, and "Continue without a sync store" takes the
  // fresh path from there (issue #4121).
  final dropped = {
    SetupStepId.setUpBackups,
    SetupStepId.setUpPhotos,
    if (draft.mode == SetupWizardMode.firstRun) ...[
      SetupStepId.welcomeFork,
      SetupStepId.existingChoice,
    ],
  };
  final trimmed = [
    for (final step in steps)
      if (!dropped.contains(step)) step,
  ];
  return trimmed.isEmpty
      ? const [...kBrowserSetUpWizardSteps, SetupStepId.finish]
      : trimmed;
}

List<SetupStepId> _stepsForPath(SetupWizardDraft draft) {
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
