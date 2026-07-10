import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
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
  appearance,
  backupSync,
  finish,
  existingChoice,
  restore,
  syncConnect,
  openFolder,
}

/// Immutable wizard draft. Nothing is persisted until Finish applies it.
class SetupWizardDraft {
  final SetupWizardMode mode;
  final SetupPath path;
  final ExistingDataSource source;
  final bool skipRequested;
  final String name;
  final AppSettings settings;
  final bool backupEnabled;
  final BackupFrequency backupFrequency;
  final bool cloudBackupEnabled;
  final CloudProviderType? connectedProvider;

  const SetupWizardDraft({
    required this.mode,
    this.path = SetupPath.undecided,
    this.source = ExistingDataSource.none,
    this.skipRequested = false,
    this.name = '',
    this.settings = const AppSettings(),
    this.backupEnabled = false,
    this.backupFrequency = BackupFrequency.weekly,
    this.cloudBackupEnabled = false,
    this.connectedProvider,
  });

  SetupWizardDraft copyWith({
    SetupPath? path,
    ExistingDataSource? source,
    bool? skipRequested,
    String? name,
    AppSettings? settings,
    bool? backupEnabled,
    BackupFrequency? backupFrequency,
    bool? cloudBackupEnabled,
    CloudProviderType? connectedProvider,
  }) {
    return SetupWizardDraft(
      mode: mode,
      path: path ?? this.path,
      source: source ?? this.source,
      skipRequested: skipRequested ?? this.skipRequested,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
      connectedProvider: connectedProvider ?? this.connectedProvider,
    );
  }

  /// Returns a copy with the six core units set to [preset].
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
    return const [
      SetupStepId.units,
      SetupStepId.appearance,
      SetupStepId.backupSync,
      SetupStepId.finish,
    ];
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
        SetupStepId.appearance,
        SetupStepId.backupSync,
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
          steps.add(SetupStepId.syncConnect);
        case ExistingDataSource.openFolder:
          steps.add(SetupStepId.openFolder);
      }
      return steps;
  }
}
