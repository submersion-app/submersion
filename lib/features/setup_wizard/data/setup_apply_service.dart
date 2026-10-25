import 'package:submersion/core/constants/place_name_language.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

final setupApplyServiceProvider = Provider<SetupApplyService>(
  (ref) => SetupApplyService(ref),
);

/// What Finish did on first run (spec 6.6).
enum FirstRunApply {
  /// Created the diver from the Profile name and the Units.
  created,

  /// The device already holds a diver, brought by a downloaded library:
  /// nothing was written, and the library's divers keep their units.
  keptExisting,

  /// No diver and no name to create one with: the Profile step is needed.
  needsName,
}

/// Persists a completed wizard draft: the profile and the units. The Set up
/// this device steps write their own choices on their own buttons.
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

  /// [deviceLanguageCodes] are the device's preferred languages, most
  /// preferred first. The first diver's place names start in the language
  /// the app itself resolves to, so a German install does not store
  /// "Germany" (issue #3111).
  Future<FirstRunApply> applyFirstRun(
    SetupWizardDraft draft, {
    Iterable<String> deviceLanguageCodes = const [],
  }) async {
    // A library downloaded in the set up steps brought its divers; a wizard
    // quit after an upload and rerun has none, and gets one here.
    if (await _ref.read(diverRepositoryProvider).getDiverCount() > 0) {
      return FirstRunApply.keptExisting;
    }
    final name = draft.name.trim();
    if (name.isEmpty) return FirstRunApply.needsName;
    final settings = draft.settings.copyWith(
      placeNameLanguage: PlaceNameLanguage.forAppLocale(
        draft.settings.locale,
        deviceLanguageCodes,
      ),
    );

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
          settings: settings,
        );
    await _ref.read(diverListNotifierProvider.notifier).refresh();

    await _ref
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(newDiver.id);
    return FirstRunApply.created;
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
    await notifier.setDistanceUnit(s.distanceUnit);
    await notifier.setGasConsumptionDisplay(s.gasConsumptionDisplay);
    await notifier.setTimeFormat(s.timeFormat);
    await notifier.setDateFormat(s.dateFormat);
    await notifier.setThemeMode(s.themeMode);
    await notifier.setThemePresetId(s.themePresetId);
    await notifier.setMapStyle(s.mapStyle);
    await notifier.setLocale(s.locale);
  }
}
