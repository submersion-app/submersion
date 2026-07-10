import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

/// Draft state for one wizard session, keyed by mode.
final setupWizardProvider = StateNotifierProvider.autoDispose
    .family<SetupWizardNotifier, SetupWizardDraft, SetupWizardMode>(
      (ref, mode) => SetupWizardNotifier(ref, mode),
    );

class SetupWizardNotifier extends StateNotifier<SetupWizardDraft> {
  final Ref _ref;

  SetupWizardNotifier(this._ref, SetupWizardMode mode)
    : super(SetupWizardDraft(mode: mode)) {
    if (mode == SetupWizardMode.settings) {
      // Seed the draft from live state so re-entry edits start from what the
      // diver already has -- and so pressing Finish without touching a step
      // re-applies the current values instead of resetting them to defaults
      // (e.g. disabling an existing backup schedule).
      final backup = _ref.read(backupSettingsProvider);
      state = state.copyWith(
        settings: _ref.read(settingsProvider),
        backupEnabled: backup.enabled,
        backupFrequency: backup.frequency,
        cloudBackupEnabled: backup.cloudBackupEnabled,
        connectedProvider: _ref.read(selectedCloudProviderTypeProvider),
      );
    }
  }

  void choosePath(SetupPath path) => state = state.copyWith(path: path);

  void chooseSource(ExistingDataSource source) =>
      state = state.copyWith(source: source);

  void requestSkip() =>
      state = state.copyWith(path: SetupPath.fresh, skipRequested: true);

  void setName(String name) => state = state.copyWith(name: name.trim());

  void applyUnitPreset(UnitPreset preset) =>
      state = state.applyingUnitPreset(preset);

  void updateSettings(AppSettings settings) =>
      state = state.copyWith(settings: settings);

  void setBackupEnabled(bool value) =>
      state = state.copyWith(backupEnabled: value);

  void setBackupFrequency(BackupFrequency value) =>
      state = state.copyWith(backupFrequency: value);

  void setCloudBackupEnabled(bool value) =>
      state = state.copyWith(cloudBackupEnabled: value);

  void setConnectedProvider(CloudProviderType? type) => state = type == null
      ? state.copyWith(clearConnectedProvider: true)
      : state.copyWith(connectedProvider: type);
}
