import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/serial_preference_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/labels_menu_model.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

export 'package:submersion/features/species_id/domain/services/labels_menu_model.dart'
    show MediaAnalysisState;

/// What the viewer draws over photos and videos for the animals the app
/// found (issue #4825): one choice on this device, for both.
class LabelModeNotifier extends StateNotifier<LabelMode>
    with SerialPreferenceWrites {
  LabelModeNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(
        LabelMode.fromId(prefs.getString(SettingsKeys.marineLifeLabelMode)),
      );

  /// Fixed state with nothing behind it, as
  /// [DeviceBadgeToggleNotifier.unstored].
  LabelModeNotifier.unstored(super.mode) : _prefs = null;

  final SharedPreferences? _prefs;

  Future<void> setMode(LabelMode mode) {
    if (state == mode) return Future<void>.value();
    state = mode;
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    return writeInTurn(
      () => prefs.setString(SettingsKeys.marineLifeLabelMode, mode.id),
    );
  }
}

/// Names, with no storage behind it; `rootProviderOverrides` gives it the
/// stored preference.
final labelModeNotifierProvider =
    StateNotifierProvider<LabelModeNotifier, LabelMode>(
      (ref) => LabelModeNotifier.unstored(LabelMode.names),
    );

/// The animals found on a photo, for the labels over it (issue #4825), as
/// the naming level in force reads them. Empty when the feature is off.
final photoDetectionsProvider = FutureProvider.autoDispose
    .family<List<MediaIdentification>, String>((ref, mediaId) async {
      if (!marineLifeLabelsShown) return const [];
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final level = ref.watch(levelInForceProvider);
      final chosen = ref.watch(namingLevelNotifierProvider);
      return [
        for (final i in await identificationsAtLevel(
          repository,
          mediaId,
          level,
          chosen: chosen,
        ))
          if (!i.isTrack) i,
      ];
    });

/// The stretches of a video analysed so far, and its length.
typedef ScanStretches = ({ScannedRanges scanned, int durationMs});

/// What the scrub bar tints while a video's scan is not finished (issue
/// #4825). Null with the feature off, for a video never scanned or whose
/// length is not known yet, and once the whole video is analysed: a
/// finished video has a plain bar.
final videoScanStretchesProvider = FutureProvider.autoDispose
    .family<ScanStretches?, String>((ref, mediaId) async {
      if (!marineLifeLabelsShown) return null;
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final run = await repository.runFor(mediaId);
      final durationMs = run?.videoDurationMs;
      if (run == null ||
          durationMs == null ||
          durationMs <= 0 ||
          run.scanComplete) {
        return null;
      }
      return (scanned: run.scanned, durationMs: durationMs);
    });

/// A photo or video, and where it was taken: what its analysis is judged
/// against. Equal for the same item and place.
class AnalysisTarget extends Equatable {
  const AnalysisTarget(this.item, this.location);

  final MediaItem item;

  /// The item's own position, else its dive's site.
  final GeoPoint? location;

  @override
  List<Object?> get props => [item.id, item.mediaType, location];
}

/// A photo or video's analysis, and how many animals it holds (those the
/// diver dismissed left out).
typedef MediaAnalysisStatus = ({MediaAnalysisState state, int found});

/// What the labels menu says of the item on screen, and which of Analyse
/// and Analyse again it offers (issue #4825). "Analysed" is what
/// processing would leave as it is (`Readiness.upToDate`), so the menu and
/// the queue never disagree.
final mediaAnalysisStatusProvider = FutureProvider.autoDispose
    .family<MediaAnalysisStatus, AnalysisTarget>((ref, target) async {
      final item = target.item;
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      // An analysis writes its crops after its rows, so follow them too.
      ref.invalidateSelfWhen(
        ref
            .watch(identificationCropStoreProvider)
            .watchChanges()
            .where((mediaId) => mediaId == item.id),
      );
      // Where no model can run, there is none to read (issue #4876).
      final installed = marineLifeIdEnabled
          ? await ref.watch(installedSpeciesPackProvider.future)
          : null;
      // Rows are only counted, so a video's track paths are not decoded.
      final (runs, stored) = await repository.forMediaIdsWithRuns([
        item.id,
      ], withPaths: false);
      final run = runs[item.id];
      // Counted as the labels show them: a run that lost a sync race leaves
      // rows that are hidden, not found (issue #4876).
      final found = visibleRows(
        run,
        stored[item.id] ?? const <MediaIdentification>[],
      ).where((i) => i.decision != IdentificationDecision.rejected).length;
      if (installed == null) {
        // Results another device found, or any where no model can run here,
        // say what was found (issue #4876); this device's own, with its
        // model since removed, say there is no model.
        final me = run == null ? null : await syncDeviceIdOrNull();
        final elsewhere =
            run != null &&
            (!marineLifeIdEnabled || (me != null && !run.madeOn(me)));
        // A video the other device left part way is not done (issue #4926).
        final partway =
            item.mediaType == MediaType.video && !(run?.scanComplete ?? false);
        return (
          state: elsewhere
              ? (partway
                    ? MediaAnalysisState.partFoundNoModel
                    : MediaAnalysisState.foundNoModel)
              // Where no model can ever be installed, an item with no results
              // is simply not analysed.
              : !marineLifeIdEnabled
              ? MediaAnalysisState.notAnalysed
              : MediaAnalysisState.noModel,
          found: found,
        );
      }
      if (run == null) {
        return (state: MediaAnalysisState.notAnalysed, found: found);
      }
      final current = await ref
          .watch(mediaIdentificationServiceProvider)
          .upToDate(
            [item],
            manifest: installed.manifest,
            locationOf: (_) => target.location,
            // Read once, above.
            read: (runs, stored),
          );
      // A video left part way is told apart from an item looked at in
      // full by other models or for another place (issue #4958).
      final partway = item.mediaType == MediaType.video && !run.scanComplete;
      return (
        state: current.contains(item.id)
            ? MediaAnalysisState.analysed
            : partway
            ? MediaAnalysisState.partial
            : MediaAnalysisState.outdated,
        found: found,
      );
    });
