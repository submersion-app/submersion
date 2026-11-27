import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/species_profile_positions.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// A dive's media and what is known about the species on it: the inputs
/// that place species on its profile besides the sightings (issue #5092).
typedef DiveSpeciesMediaInputs = ({
  List<MediaItem> media,
  Map<String, List<MediaSpeciesTag>> tagsByMedia,
  Map<String, List<MediaIdentification>> identificationsByMedia,
});

/// [DiveSpeciesMediaInputs] for a dive, by dive id. Refreshes when a tag,
/// a media row or an identification changes.
final diveSpeciesMediaInputsProvider =
    FutureProvider.family<DiveSpeciesMediaInputs, String>((ref, diveId) async {
      final tags = ref.watch(mediaSpeciesRepositoryProvider);
      final identifications = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(tags.watchTagChanges());
      ref.invalidateSelfWhen(identifications.watchChanges());
      final media = await ref.watch(mediaForDiveProvider(diveId).future);
      final ids = [for (final m in media) m.id];
      if (ids.isEmpty) {
        return (
          media: media,
          tagsByMedia: const <String, List<MediaSpeciesTag>>{},
          identificationsByMedia: const <String, List<MediaIdentification>>{},
        );
      }
      return (
        media: media,
        tagsByMedia: await tags.getTagsForMediaIds(ids),
        identificationsByMedia: await identifications.forMediaIds(
          ids,
          withPaths: false,
        ),
      );
    });

/// The species highlighted on a dive's profile, by species id; null for
/// none. One per dive and kept for the session, like the selected safety
/// finding.
final selectedProfileSpeciesProvider = StateProvider.family<String?, String>(
  (ref, diveId) => null,
);

/// Selects [speciesId] on [diveId]'s profile, or clears it when it is
/// selected already. Selecting clears the dive's selected safety finding:
/// the chart emphasises one thing at a time.
void toggleProfileSpecies(WidgetRef ref, String diveId, String speciesId) {
  final selected = ref.read(selectedProfileSpeciesProvider(diveId).notifier);
  if (selected.state == speciesId) {
    selected.state = null;
    return;
  }
  selected.state = speciesId;
  ref.read(selectedSafetyFindingProvider(diveId).notifier).state = null;
}

/// Selects [finding] on [diveId]'s profile, or clears it when it is
/// selected already, and says whether it is now selected. Selecting clears
/// the highlighted species: the chart emphasises one thing at a time. The
/// one rule for the findings card and the chart's safety lane.
bool toggleSafetyFinding(WidgetRef ref, String diveId, SafetyFinding finding) {
  final selected = ref.read(selectedSafetyFindingProvider(diveId).notifier);
  if (selected.state?.id == finding.id) {
    selected.state = null;
    return false;
  }
  selected.state = finding;
  ref.read(selectedProfileSpeciesProvider(diveId).notifier).state = null;
  return true;
}

final Expando<
  ({
    DiveSpeciesMediaInputs inputs,
    List<DiveProfilePoint> profile,
    Map<String, SpeciesProfilePositions> positions,
  })
>
_positionsMemo = Expando('speciesProfilePositions');

/// Each sighted species' positions on the profile the chart draws for
/// [dive] (its active source's), by species id. Empty while anything loads.
Map<String, SpeciesProfilePositions> watchSpeciesPositions(
  WidgetRef ref,
  Dive dive,
) {
  final sightings = ref.watch(diveSightingsProvider(dive.id)).value;
  final inputs = ref.watch(diveSpeciesMediaInputsProvider(dive.id)).value;
  final profile = watchChartProfile(ref, dive);
  if (sightings == null || inputs == null) return const {};
  final cached = _positionsMemo[sightings];
  if (cached != null &&
      identical(cached.inputs, inputs) &&
      identical(cached.profile, profile)) {
    return cached.positions;
  }
  final positions = speciesProfilePositions(
    sightings: sightings,
    media: inputs.media,
    tagsByMedia: inputs.tagsByMedia,
    identificationsByMedia: inputs.identificationsByMedia,
    profile: profile,
  );
  _positionsMemo[sightings] = (
    inputs: inputs,
    profile: profile,
    positions: positions,
  );
  return positions;
}

/// What the chart and the pinned strip draw for the selected species.
@immutable
class SpeciesProfileHighlight {
  const SpeciesProfileHighlight({required this.positions, required this.color});

  final SpeciesProfilePositions positions;

  /// The species' category colour, the same as its row's avatar.
  final Color color;
}

/// The highlight for the species selected on [dive]'s profile, or null when
/// none is selected or the selected one has no position.
SpeciesProfileHighlight? watchSpeciesHighlight(
  WidgetRef ref,
  Dive dive, {
  required Brightness brightness,
}) {
  final speciesId = ref.watch(selectedProfileSpeciesProvider(dive.id));
  if (speciesId == null) return null;
  final positions = watchSpeciesPositions(ref, dive)[speciesId];
  if (positions == null || positions.isEmpty) return null;
  final sightings =
      ref.watch(diveSightingsProvider(dive.id)).value ?? const <Sighting>[];
  final category = sightings
      .where((s) => s.speciesId == speciesId)
      .firstOrNull
      ?.speciesCategory;
  return SpeciesProfileHighlight(
    positions: positions,
    color: colorForSpeciesCategory(category, brightness),
  );
}
