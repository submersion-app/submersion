import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

/// Whether the diver dismissed the offer to download the identification
/// model (issue #4773). Per device, off by default.
class SpeciesDownloadPromptDismissedNotifier extends DeviceBadgeToggleNotifier {
  SpeciesDownloadPromptDismissedNotifier(SharedPreferences prefs)
    : super(
        prefs,
        SettingsKeys.speciesIdDownloadPromptDismissed,
        defaultValue: false,
      );

  /// Fixed state with nothing behind it; see
  /// [DeviceBadgeToggleNotifier.unstored].
  SpeciesDownloadPromptDismissedNotifier.unstored(bool dismissed)
    : super.unstored(dismissed, SettingsKeys.speciesIdDownloadPromptDismissed);
}

/// Not dismissed, with no storage behind it; `rootProviderOverrides` gives
/// it the stored preference.
final speciesDownloadPromptDismissedProvider =
    StateNotifierProvider<SpeciesDownloadPromptDismissedNotifier, bool>(
      (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
    );

/// Whether to offer the identification model to a diver who has none
/// (issue #4773): the feature is on, the model can run on this device, none
/// is installed, and the diver has not dismissed the offer.
///
/// Asks nothing of the network. What the pack controller already knows
/// (from a visit to the settings page) still counts: no offer while a
/// download runs, nor once it is known that none can be had here.
final speciesDownloadPromptProvider = Provider<bool>((ref) {
  if (!marineLifeIdEnabled) return false;
  if (ref.watch(speciesDownloadPromptDismissedProvider)) return false;
  final availability = ref.watch(visionAvailabilityProvider).value;
  if (availability != VisionAvailability.available) return false;
  final installed = ref.watch(installedSpeciesPackProvider);
  if (!installed.hasValue || installed.value != null) return false;
  return switch (ref.watch(speciesPackControllerProvider)) {
    PackChecking() || PackNotInstalled() || PackFailed() => true,
    _ => false,
  };
});
