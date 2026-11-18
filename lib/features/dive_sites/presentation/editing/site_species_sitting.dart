import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The site's expected species, edited on the Marine Life card (issue
/// #4527, phase 2).
///
/// Written at Save, after the site: a loaded species the diver dropped is
/// removed, one the sitting added is added. A species stored meanwhile (a
/// sync) that the sitting never loaded is not touched, where the old
/// delete-all-then-add-each would have dropped it. The order carries no
/// meaning.
final siteSpeciesList = SittingList<DiveSite, SiteSpeciesEntry>(
  key: 'site.species',
  cardId: SiteDetailSectionId.marineLife.name,
  read: (site) => SpeciesRepository().getExpectedSpeciesForSite(site.id),
  write: (site, loaded, current) async {
    final repository = SpeciesRepository();
    final kept = {for (final e in current) e.speciesId};
    final had = {for (final e in loaded) e.speciesId};
    final stored = {
      for (final e in await repository.getExpectedSpeciesForSite(site.id))
        e.speciesId,
    };
    // Written without a stamp each: the sitting stamps the library once it
    // has committed. It is offered only where this profile may edit.
    var changed = false;
    for (final id in had.difference(kept)) {
      if (!stored.contains(id)) continue;
      await repository.removeExpectedSpecies(site.id, id, stampLibrary: false);
      changed = true;
    }
    for (final entry in current) {
      if (had.contains(entry.speciesId) || stored.contains(entry.speciesId)) {
        continue;
      }
      changed = true;
      await repository.addExpectedSpecies(
        siteId: site.id,
        speciesId: entry.speciesId,
        notes: entry.notes,
        stampLibrary: false,
      );
    }
    return changed;
  },
  same: (a, b) => sameIdSets(a, b, (e) => e.speciesId),
);

/// [species] as a new expected species of [siteId], drawn as stored ones
/// are until Save writes it under an id of the database's own.
SiteSpeciesEntry newSiteSpeciesEntry(String siteId, Species species) =>
    SiteSpeciesEntry(
      id: const Uuid().v4(),
      siteId: siteId,
      speciesId: species.id,
      speciesName: species.commonName,
      category: species.category,
      createdAt: DateTime.now(),
    );
