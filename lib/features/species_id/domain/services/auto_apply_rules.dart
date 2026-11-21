/// When the app may tag a species with no tap (issue #4727). Pure, so every
/// screen and service decides alike.
library;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

/// A bar above 1 is "never": a score is a share of at most 1.
bool _reachable(double bar) => bar <= 1;

/// Whether [naming] can ever call a match confident, with a place or
/// without one. When it cannot, auto-apply has nothing to do.
bool packCanApply(NamingConfig naming) =>
    _reachable(naming.confidentScore) ||
    _reachable(naming.confidentScoreNoLocation);

/// Whether [naming] calls a match confident only when the media has a
/// usable place (Megalodon alone, measured 2026-11-17).
bool packAppliesOnlyWithPlace(NamingConfig naming) =>
    _reachable(naming.confidentScore) &&
    !_reachable(naming.confidentScoreNoLocation);

/// One species to tag on a media item, with the identifications it covers.
class SpeciesToApply {
  const SpeciesToApply({
    required this.candidate,
    required this.identificationIds,
  });

  /// The best-scoring of the covered identifications' top names.
  final NamedCandidate candidate;
  final List<String> identificationIds;
}

/// What auto-apply tags on one media item: undecided identifications the
/// app was confident of when they were named, one entry per species, less
/// species already tagged. Decided ones are never reconsidered, so a
/// species the diver removed is never applied again there; nor is one a
/// re-analysis the diver asked for brought back from a dismissal
/// ([MediaIdentification.reopened], issue #4825).
///
/// On a video only tracks the app could suggest count, and only once the
/// whole video has been scanned ([scanComplete]): live naming renames a
/// fish when it gets a better view, so an early chunk's name would fix a
/// worse guess in the log.
List<SpeciesToApply> identificationsToApply(
  List<MediaIdentification> all,
  List<TaggedSpecies> tagged, {
  required bool isVideo,
  required bool scanComplete,
}) {
  if (isVideo && !scanComplete) return const [];
  final groups = <int, List<MediaIdentification>>{};
  for (final i in all) {
    final top = i.top;
    if (top == null ||
        !i.confident ||
        i.decision != IdentificationDecision.undecided ||
        i.reopened ||
        (isVideo && (!i.isTrack || !i.suggestable)) ||
        tagged.any((t) => candidateMatches(top.candidate, t))) {
      continue;
    }
    groups.putIfAbsent(top.candidate.gbifKey, () => []).add(i);
  }
  return [
    for (final group in groups.values)
      SpeciesToApply(
        candidate: group
            .map((i) => i.top!)
            .reduce((a, b) => b.score > a.score ? b : a),
        identificationIds: [for (final i in group) i.id],
      ),
  ];
}
