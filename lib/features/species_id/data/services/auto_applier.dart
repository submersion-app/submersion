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
/// [timing], links or logs its sighting. The existing reconcile then
/// accepts the identifications behind it. Never throws for one item: a
/// species that cannot be tagged is left for the next time.
class AutoApplier {
  AutoApplier({
    required MediaIdentificationRepository identifications,
    required SuggestionAcceptor acceptor,
    required SpeciesTaggingService tagging,
    required bool Function() enabled,
    required SightingTiming Function() timing,
  }) : _identifications = identifications,
       _acceptor = acceptor,
       _tagging = tagging,
       _enabled = enabled,
       _timing = timing;

  final MediaIdentificationRepository _identifications;
  final SuggestionAcceptor _acceptor;
  final SpeciesTaggingService _tagging;

  /// The auto-apply setting on this device.
  final bool Function() _enabled;
  final SightingTiming Function() _timing;
  final _log = LoggerService.forClass(AutoApplier);

  bool get isOn => marineLifeIdEnabled && _enabled();

  /// [apply] filed as one automatic History entry of its own, as applying
  /// from the viewer is. Returns how many species it tagged. The entry
  /// opens only once there is something to tag, so a photo with nothing
  /// confident leaves none, and a save the diver makes meanwhile is never
  /// filed under it.
  Future<int> applyInScope(String mediaId, {required bool isVideo}) async {
    if (!isOn) return 0;
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
          return (await _tagPicked(mediaId, picked)).length;
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
  }) async => identificationsToApply(
    await _identifications.forMedia(mediaId),
    await _identifications.taggedSpecies(mediaId),
    isVideo: isVideo,
    scanComplete:
        (await _identifications.runFor(mediaId))?.scanComplete ?? false,
  );

  /// [apply] over a Find species run's [items], filed as one automatic
  /// History entry for the whole run (issue #4727). The scope opens only
  /// now, at the run's end, so a save the diver made during the run is not
  /// filed under it. Returns how many distinct species it tagged.
  Future<int> applyAllInScope(List<RunAppliedItem> items) {
    if (!isOn || items.isEmpty) return Future.value(0);
    return ChangeLogScope.automatic(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.marineLifeId,
      body: () async {
        final species = <String>{};
        for (final item in items) {
          species.addAll(await _applyItem(item.mediaId, isVideo: item.isVideo));
        }
        return species.length;
      },
    );
  }

  /// Tags what [identificationsToApply] picks on [mediaId], with no scope
  /// of its own: a run files all of its items under one.
  Future<int> apply(String mediaId, {required bool isVideo}) async =>
      (await _applyItem(mediaId, isVideo: isVideo)).length;

  /// The species [apply] tagged on [mediaId]. A species that cannot be
  /// tagged (its photo deleted meanwhile, say) is logged and skipped, and
  /// an item whose rows cannot be read tags nothing: never throws.
  Future<Set<String>> _applyItem(
    String mediaId, {
    required bool isVideo,
  }) async {
    if (!isOn) return const {};
    try {
      return await _tagAll(mediaId, isVideo: isVideo);
    } on Object catch (e) {
      _log.debug('Could not auto-apply on $mediaId', error: e);
      return const {};
    }
  }

  Future<Set<String>> _tagAll(String mediaId, {required bool isVideo}) async =>
      _tagPicked(mediaId, await _picks(mediaId, isVideo: isVideo));

  Future<Set<String>> _tagPicked(
    String mediaId,
    List<SpeciesToApply> picked,
  ) async {
    final tagged = <String>{};
    for (final s in picked) {
      try {
        final resolved = await _acceptor.resolveWithOrigin(
          s.candidate.candidate,
        );
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
    if (tagged.isNotEmpty) await _reconcile(mediaId);
    return tagged;
  }

  /// The decisions in step with the new tags, as the service's reconcile
  /// records them.
  Future<void> _reconcile(String mediaId) async {
    final changed = reconcileDecisions(
      await _identifications.forMedia(mediaId),
      await _identifications.taggedSpecies(mediaId),
      now: DateTime.now().toUtc(),
    );
    if (changed.isNotEmpty) await _identifications.updateDecisions(changed);
  }
}
