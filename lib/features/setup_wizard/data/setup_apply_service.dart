import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

final setupApplyServiceProvider = Provider<SetupApplyService>(
  (ref) => SetupApplyService(ref),
);

/// Persists a completed wizard draft.
///
/// First-run ordering is load-bearing: the diver's settings row must hold
/// the draft from the moment the diver exists. The SettingsNotifier can
/// load that row before this service reaches setCurrentDiver, because on a
/// fresh database the active-diver notifier resolves to the new default
/// diver on the divers-table tick alone. A row seeded with defaults and
/// overwritten afterwards left the notifier on the defaults, and the next
/// settings write saved them over the draft (#2298).
class SetupApplyService {
  final Ref _ref;

  SetupApplyService(this._ref);

  Future<void> applyFirstRun(SetupWizardDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Diver name must not be empty');
    }

    final now = DateTime.now();
    // Created with the draft as its settings, in the same transaction as
    // the diver (see class doc).
    final newDiver = await _ref
        .read(diverRepositoryProvider)
        .createDiver(
          Diver(
            id: '',
            name: name,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
          ),
          settings: draft.settings,
        );
    await _ref.read(diverListNotifierProvider.notifier).refresh();

    await _ref
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(newDiver.id);

    await _applyBackupChoices(draft);
  }

  Future<void> applySettingsMode(SetupWizardDraft draft) async {
    // Re-entry: the current diver's settings row exists and the
    // SettingsNotifier is loaded, so the existing setters are race-free.
    final notifier = _ref.read(settingsProvider.notifier);
    final s = draft.settings;
    await notifier.setDepthUnit(s.depthUnit);
    await notifier.setTemperatureUnit(s.temperatureUnit);
    await notifier.setPressureUnit(s.pressureUnit);
    await notifier.setVolumeUnit(s.volumeUnit);
    await notifier.setWeightUnit(s.weightUnit);
    await notifier.setAltitudeUnit(s.altitudeUnit);
    await notifier.setGasConsumptionDisplay(s.gasConsumptionDisplay);
    await notifier.setTimeFormat(s.timeFormat);
    await notifier.setDateFormat(s.dateFormat);
    await notifier.setThemeMode(s.themeMode);
    await notifier.setThemePresetId(s.themePresetId);
    await notifier.setMapStyle(s.mapStyle);
    await notifier.setLocale(s.locale);

    await _applyBackupChoices(draft);
  }

  Future<void> _applyBackupChoices(SetupWizardDraft draft) async {
    final backup = _ref.read(backupSettingsProvider.notifier);
    await backup.setEnabled(draft.backupEnabled);
    if (draft.backupEnabled) {
      await backup.setFrequency(draft.backupFrequency);
    }
    // Apply the cloud-copy choice in both directions so re-entry can turn it
    // off. The flag is inert without a configured provider, so writing it is
    // safe even when none is connected.
    await backup.setCloudBackupEnabled(draft.cloudBackupEnabled);
  }
}
