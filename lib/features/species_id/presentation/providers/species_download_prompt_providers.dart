import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
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
final speciesDownloadPromptDismissedNotifierProvider =
    StateNotifierProvider<SpeciesDownloadPromptDismissedNotifier, bool>(
      (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
    );

/// Whether to offer the identification model to a diver who has none
/// (issue #4773): the feature is on, the model can run on this device, none
/// is installed, and the diver has not dismissed the offer.
///
/// Never in the sample logbook (issue #4891): demo mode shares the device's
/// preferences, so closing the offer on a sample dive would hide it in the
/// diver's own logbook too.
///
/// Asks nothing of the network. What the pack controller already knows
/// (from a visit to the settings page) still counts: no offer while a
/// download runs, nor once it is known that none can be had here.
final speciesDownloadPromptProvider = Provider<bool>((ref) {
  if (ref.watch(demoModeActiveProvider)) return false;
  if (!marineLifeIdEnabled) return false;
  if (ref.watch(speciesDownloadPromptDismissedNotifierProvider)) return false;
  final availability = ref.watch(visionAvailabilityProvider).value;
  if (availability != VisionAvailability.available) return false;
  final installed = ref.watch(installedSpeciesPackProvider);
  if (!installed.hasValue || installed.value != null) return false;
  return switch (ref.watch(speciesPackControllerProvider)) {
    PackChecking() || PackNotInstalled() || PackFailed() => true,
    _ => false,
  };
});

/// Whether the library holds any photo or video, whatever it is attached
/// to (issue #4881): the count the Photos step of Set up this device uses.
final libraryHasPhotosOrVideosProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final media = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(media.watchMediaChanges());
  return await media.countPhotosAndVideos() > 0;
});

/// Whether Home offers the identification model (issue #4881): the offer
/// is wanted, the library has a photo or video for the model to look at,
/// and the sample logbook is not open. Demo mode shares the device's
/// preferences, so a dismissal made there would carry into the diver's own
/// setup. Auto-disposed, so the library watch ends when Home goes.
///
/// Cheap checks first: the offer itself asks the vision engine (which loads
/// ONNX Runtime on Android, Windows and Linux) and the pack store, so it is
/// asked last, and never for a library with nothing for the model to see.
/// An installed model (a cached file check) ends the library watch too:
/// installing dismisses nothing, and the banner can never show again.
final homeSpeciesBannerProvider = Provider.autoDispose<bool>((ref) {
  if (ref.watch(demoModeActiveProvider)) return false;
  if (!marineLifeIdEnabled) return false;
  if (ref.watch(speciesDownloadPromptDismissedNotifierProvider)) return false;
  if (ref.watch(installedSpeciesPackProvider).value != null) return false;
  if (!(ref.watch(libraryHasPhotosOrVideosProvider).value ?? false)) {
    return false;
  }
  return ref.watch(speciesDownloadPromptProvider);
});

/// Whether the setup wizard offers the species model (issue #4881), by the
/// facts the #4773 offers use: the feature is on, the model can run on this
/// device, none is installed, and the diver has not dismissed the offer (a
/// removal dismisses it too). Read once, as a snapshot: it never follows
/// the pack controller, so a download started from the step keeps the step.
///
/// It watches what it awaits: a future read with `ref.read` leaves its
/// provider with no listener, and a reload of the installed pack mid-read
/// (a download from Settings finishing) would then never answer (issue
/// #3807).
final speciesModelOfferProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!marineLifeIdEnabled) return false;
  if (ref.watch(speciesDownloadPromptDismissedNotifierProvider)) return false;
  final availability = await ref.watch(visionAvailabilityProvider.future);
  if (availability != VisionAvailability.available) return false;
  return await ref.watch(installedSpeciesPackProvider.future) == null;
});
