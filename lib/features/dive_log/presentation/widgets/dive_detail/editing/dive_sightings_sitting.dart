import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The dive's sightings, edited on the Sightings card.
///
/// Written at Save, after the dive, as the old dive form's save wrote them: a
/// loaded sighting missing now is deleted, a loaded one changed is updated, and
/// one the sitting added (an id that was not loaded) is added under an id of
/// the database's own. A sighting stored meanwhile that the sitting never
/// loaded is not touched. The order carries no meaning.
final diveSightingsList = SittingList<Dive, Sighting>(
  key: 'sightings',
  cardId: DiveDetailSectionId.sightings.name,
  read: (dive) => SpeciesRepository().getSightingsForDive(dive.id),
  write: (dive, loaded, current) async {
    final repository = SpeciesRepository();
    final loadedById = {for (final s in loaded) s.id: s};
    final currentIds = {for (final s in current) s.id};
    // Only rows still on this dive: one a sync moved to another dive since
    // the sitting read it is that dive's now (issue #4527).
    final onDive = {
      for (final s in await repository.getSightingsForDive(dive.id)) s.id,
    };
    for (final sighting in loaded) {
      if (!currentIds.contains(sighting.id) && onDive.contains(sighting.id)) {
        await repository.deleteSighting(sighting.id);
      }
    }
    for (final sighting in current) {
      final before = loadedById[sighting.id];
      if (before != null && !onDive.contains(sighting.id)) continue;
      if (before == null) {
        await repository.addSighting(
          diveId: dive.id,
          speciesId: sighting.speciesId,
          abundance: sighting.abundance,
          count: sighting.count,
          notes: sighting.notes,
        );
      } else if (before != sighting) {
        await repository.updateSighting(sighting);
      }
    }
    // Whether it changed anything is not asked of a dive's rows.
    return null;
  },
  same: (a, b) => setEquals(a.toSet(), b.toSet()),
);
