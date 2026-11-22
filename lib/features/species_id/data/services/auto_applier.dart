import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

/// Tags the species the app is confident of on a media item, with no tap
/// (issue #4727). Each tag is marked unconfirmed and, by the diver's
/// [timing], links or logs its sighting. The identification service's
/// [reconcile] then accepts the identifications behind it, at the naming
/// level in force. Never throws for one item: a species that cannot be
/// tagged is left for the next time.
class AutoApplier {
  AutoApplier({
    required MediaIdentificationRepository identifications,
    required SuggestionAcceptor acceptor,
    required SpeciesTaggingService tagging,
    required bool Function() enabled,
    required SightingTiming Function() timing,
    required Future<void> Function(String mediaId) reconcile,
    required int Function() databaseGeneration,
    required bool Function() packAllows,
    Future<String?> Function()? deviceId,
  }) : _identifications = identifications,
       _acceptor = acceptor,
       _tagging = tagging,
       _enabled = enabled,
       _timing = timing,
       _reconcile = reconcile,
       _generation = databaseGeneration,
       _packAllows = packAllows,
       _deviceId = deviceId ?? (() async => null);

  final MediaIdentificationRepository _identifications;
  final SuggestionAcceptor _acceptor;
  final SpeciesTaggingService _tagging;

  /// The auto-apply setting on this device.
  final bool Function() _enabled;
  final SightingTiming Function() _timing;

  /// The identification service's reconcile: which identifications a tag
  /// accepts follows the naming level (issue #4721), so it is not redone
  /// here from the stored flags.
  final Future<void> Function(String mediaId) _reconcile;

  /// Moves when another logbook is opened. Each apply names the logbook its
  /// identifications were read in, and writes nothing once another is open.
  final int Function() _generation;

  /// Whether the installed pack can call a match confident at all
  /// (`packCanApply`), as the setting shows; true with none installed,
  /// when the names already stored still count (issue #4727).
  final bool Function() _packAllows;

  /// This device's sync id, or null when unknown. Only the device that made
  /// a run applies from it (issue #4876): the tags it writes sync, so a
  /// device that received the run never tags it a second time.
  final Future<String?> Function() _deviceId;
  final _log = LoggerService.forClass(AutoApplier);

  bool get isOn => marineLifeIdEnabled && _enabled() && _packAllows();

  /// Applies on [mediaId] as one automatic History entry of its own, as applying
  /// from the viewer is. Returns how many species it tagged. The entry
  /// opens only once there is something to tag, so a photo with nothing
  /// confident leaves none, and a save the diver makes meanwhile is never
  /// filed under it.
  ///
  /// [generation] is the logbook the item was looked at in.
  Future<int> applyInScope(
    String mediaId, {
    required bool isVideo,
    required int generation,
  }) async {
    if (!isOn || _generation() != generation) return 0;
    final List<SpeciesToApply> picked;
    try {
      picked = await _picks(mediaId, isVideo: isVideo);
    } on Object catch (e) {
      _log.debug('Could not read what to apply on $mediaId', error: e);
      return 0;
    }
    if (picked.isEmpty) return 0;
    return ChangeLogScope.automatic(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.marineLifeId,
      body: () async {
        try {
          return (await _tagPicked(mediaId, picked, generation)).length;
        } on Object catch (e) {
          _log.debug('Could not auto-apply on $mediaId', error: e);
          return 0;
        }
      },
    );
  }

  Future<List<SpeciesToApply>> _picks(
    String mediaId, {
    required bool isVideo,
  }) async {
    final run = await _identifications.runFor(mediaId);
    final me = await _deviceId();
    if (run != null && me != null && !run.madeOn(me)) return const [];
    return identificationsToApply(
      // As the labels show them: a leftover of a run that lost a sync race
      // is hidden, so it never tags (issue #4876).
      visibleRows(run, await _identifications.forMedia(mediaId)),
      await _identifications.taggedSpecies(mediaId),
      isVideo: isVideo,
      scanComplete: run?.scanComplete ?? false,
    );
  }

  /// Applies over a Find species run's [items], filed as one automatic
  /// History entry for the whole run (issue #4727). The scope opens only
  /// now, at the run's end, so a save the diver made during the run is not
  /// filed under it. Returns how many distinct species it tagged.
  ///
  /// [generation] is the logbook the run looked at its items in.
  Future<int> applyAllInScope(
    List<RunAppliedItem> items, {
    required int generation,
  }) {
    if (!isOn || items.isEmpty || _generation() != generation) {
      return Future.value(0);
    }
    return ChangeLogScope.automatic(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.marineLifeId,
      body: () async {
        final species = <String>{};
        for (final item in items) {
          species.addAll(
            await _applyItem(
              item.mediaId,
              isVideo: item.isVideo,
              generation: generation,
            ),
          );
        }
        return species.length;
      },
    );
  }

  /// The species tagged on [mediaId], with no History scope of its own (a
  /// run files all of its items under one). A species that cannot be
  /// tagged (its photo deleted meanwhile, say) is logged and skipped, and
  /// an item whose rows cannot be read tags nothing: never throws.
  Future<Set<String>> _applyItem(
    String mediaId, {
    required bool isVideo,
    required int generation,
  }) async {
    if (!isOn || _generation() != generation) return const {};
    try {
      return await _tagAll(mediaId, isVideo: isVideo, generation: generation);
    } on Object catch (e) {
      _log.debug('Could not auto-apply on $mediaId', error: e);
      return const {};
    }
  }

  Future<Set<String>> _tagAll(
    String mediaId, {
    required bool isVideo,
    required int generation,
  }) async =>
      _tagPicked(mediaId, await _picks(mediaId, isVideo: isVideo), generation);

  Future<Set<String>> _tagPicked(
    String mediaId,
    List<SpeciesToApply> picked,
    int generation,
  ) async {
    final tagged = <String>{};
    for (final s in picked) {
      // Another logbook opened: nothing is written there, a species the
      // resolver would create included.
      if (_generation() != generation) break;
      try {
        final resolved = await _acceptor.resolveWithOrigin(
          s.candidate.candidate,
          mayCreate: () => _generation() == generation,
        );
        // Another logbook opened meanwhile: nothing more is written there.
        if (_generation() != generation) break;
        await _tagging.applyAppTag(
          mediaId: mediaId,
          speciesId: resolved.species.id,
          timing: _timing(),
          createdSpecies: resolved.created,
        );
        tagged.add(resolved.species.id);
      } on Object catch (e) {
        _log.debug('Could not tag a species on $mediaId', error: e);
      }
    }
    if (tagged.isNotEmpty && _generation() == generation) {
      await _reconcile(mediaId);
    }
    return tagged;
  }
}
