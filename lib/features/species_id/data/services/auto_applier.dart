import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
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

  bool get isOn => marineLifeIdEnabled && _enabled();

  /// [apply] filed as one automatic History entry of its own, as applying
  /// from the viewer is. Returns how many species it tagged.
  Future<int> applyInScope(String mediaId, {required bool isVideo}) {
    if (!isOn) return Future.value(0);
    return ChangeLogScope.automatic(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.marineLifeId,
      body: () => apply(mediaId, isVideo: isVideo),
    );
  }

  /// [apply] over a Find species run's [items], filed as one automatic
  /// History entry for the whole run (issue #4727). The scope opens only
  /// now, at the run's end, so a save the diver made during the run is not
  /// filed under it. Returns how many species it tagged.
  Future<int> applyAllInScope(List<RunAppliedItem> items) {
    if (!isOn || items.isEmpty) return Future.value(0);
    return ChangeLogScope.automatic(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.marineLifeId,
      body: () async {
        var tagged = 0;
        for (final item in items) {
          tagged += await apply(item.mediaId, isVideo: item.isVideo);
        }
        return tagged;
      },
    );
  }

  /// Tags what [identificationsToApply] picks on [mediaId], with no scope
  /// of its own: a run files all of its items under one.
  Future<int> apply(String mediaId, {required bool isVideo}) async {
    if (!isOn) return 0;
    final picked = identificationsToApply(
      await _identifications.forMedia(mediaId),
      await _identifications.taggedSpecies(mediaId),
      isVideo: isVideo,
      scanComplete:
          (await _identifications.runFor(mediaId))?.scanComplete ?? false,
    );
    var tagged = 0;
    for (final s in picked) {
      final resolved = await _acceptor.resolveWithOrigin(s.candidate.candidate);
      await _tagging.applyAppTag(
        mediaId: mediaId,
        speciesId: resolved.species.id,
        timing: _timing(),
        createdSpecies: resolved.created,
      );
      tagged++;
    }
    if (tagged > 0) await _reconcile(mediaId);
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
