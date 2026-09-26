import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Builds the labels the resolver matches against, one query per kind. Ids
/// and labels only, so a 5,000-dive library builds it in well under a second.
class NameIndexBuilder {
  NameIndexBuilder({
    required this.sites,
    required this.species,
    required this.equipment,
    required this.buddies,
    required this.dives,
    required this.tags,
    required this.centers,
    required this.trips,
    required this.computers,
  });

  final SiteRepository sites;
  final SpeciesRepository species;
  final EquipmentRepository equipment;
  final BuddyRepository buddies;
  final DiveRepository dives;
  final TagRepository tags;
  final DiveCenterRepository centers;
  final TripRepository trips;
  final DiveComputerRepository computers;

  Future<NameIndex> build({
    required String? diverId,
    required AppLocalizations l10n,
  }) async {
    final results = await Future.wait<Object>([
      sites.getAllSites(diverId: diverId),
      species.getAllSpecies(),
      equipment.getAllEquipment(diverId: diverId),
      buddies.getAllBuddies(diverId: diverId),
      dives.getDistinctLegacyBuddyNames(diverId: diverId),
      tags.getAllTags(diverId: diverId),
      centers.getAllDiveCenters(diverId: diverId),
      trips.getAllTrips(diverId: diverId),
      computers.getAllComputers(diverId: diverId),
    ]);
    return fromEntities(
      sites: results[0] as List<DiveSite>,
      species: results[1] as List<Species>,
      equipment: results[2] as List<EquipmentItem>,
      buddies: results[3] as List<Buddy>,
      legacyBuddyNames: results[4] as List<String>,
      tags: results[5] as List<Tag>,
      centers: results[6] as List<DiveCenter>,
      trips: results[7] as List<Trip>,
      computers: results[8] as List<DiveComputer>,
      l10n: l10n,
    );
  }

  /// Pure assembly, so tests need no database.
  static NameIndex fromEntities({
    required List<DiveSite> sites,
    required List<Species> species,
    required List<EquipmentItem> equipment,
    required List<Buddy> buddies,
    required List<String> legacyBuddyNames,
    required List<Tag> tags,
    required List<DiveCenter> centers,
    required List<Trip> trips,
    required List<DiveComputer> computers,
    required AppLocalizations l10n,
  }) {
    final entries = <NameEntry>[];

    // Places: country 0, region 1, island 2, city 3; the same label merges
    // into one entry keeping the lowest rank and the union of site ids.
    final placeRanks = <String, int>{};
    final placeIds = <String, Set<String>>{};
    void place(String? label, int rank, String siteId) {
      if (label == null || label.trim().isEmpty) return;
      final key = label.trim();
      placeIds.putIfAbsent(key, () => {}).add(siteId);
      final existing = placeRanks[key];
      if (existing == null || rank < existing) placeRanks[key] = rank;
    }

    for (final s in sites) {
      place(s.country, 0, s.id);
      place(s.region, 1, s.id);
      place(s.island, 2, s.id);
      place(s.city, 3, s.id);
      entries.add(
        NameEntry(
          kind: MentionKind.site,
          label: s.name,
          ids: [s.id],
          target: NameTarget.siteId,
        ),
      );
    }
    for (final label in placeRanks.keys) {
      entries.add(
        NameEntry(
          kind: MentionKind.place,
          label: label,
          ids: placeIds[label]!.toList(),
          target: NameTarget.sitePlace,
          rank: placeRanks[label]!,
        ),
      );
    }

    for (final sp in species) {
      final localized = sp.isBuiltIn ? builtInSpeciesName(l10n, sp.id) : null;
      if (localized != null) {
        entries.add(
          NameEntry(
            kind: MentionKind.species,
            label: localized,
            ids: [sp.id],
            target: NameTarget.speciesId,
          ),
        );
      }
      entries.add(
        NameEntry(
          kind: MentionKind.species,
          label: sp.commonName,
          ids: [sp.id],
          target: NameTarget.speciesId,
          rank: 1,
        ),
      );
      final sci = sp.scientificName;
      if (sci != null && sci.isNotEmpty) {
        entries.add(
          NameEntry(
            kind: MentionKind.species,
            label: sci,
            ids: [sp.id],
            target: NameTarget.speciesId,
            rank: 2,
          ),
        );
      }
    }

    for (final e in equipment) {
      entries.add(
        NameEntry(
          kind: MentionKind.gear,
          label: e.name,
          ids: [e.id],
          target: NameTarget.equipmentId,
        ),
      );
      final brandModel = [
        e.brand,
        e.model,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      if (brandModel.isNotEmpty && brandModel != e.name) {
        entries.add(
          NameEntry(
            kind: MentionKind.gear,
            label: brandModel,
            ids: [e.id],
            target: NameTarget.equipmentId,
            rank: 1,
          ),
        );
      }
    }
    // Attribute choices: every choice of every curated choice attribute, by
    // its localized label, so "trilaminate" lowers to a condition.
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        if (def.kind != AttributeKind.choice) continue;
        for (final choice in def.choiceKeys) {
          entries.add(
            NameEntry(
              kind: MentionKind.gear,
              label: attributeChoiceLabel(l10n, def.key, choice),
              ids: const [],
              target: NameTarget.attrChoice,
              rank: 2,
              attrKey: def.key,
              attrChoice: choice,
            ),
          );
        }
      }
    }

    for (final b in buddies) {
      entries.add(
        NameEntry(
          kind: MentionKind.buddy,
          label: b.name,
          ids: [b.id],
          target: NameTarget.buddyId,
        ),
      );
    }
    for (final name in legacyBuddyNames) {
      entries.add(
        NameEntry(
          kind: MentionKind.buddy,
          label: name,
          ids: const [],
          target: NameTarget.legacyBuddyName,
          rank: 1,
        ),
      );
    }
    for (final t in tags) {
      entries.add(
        NameEntry(
          kind: MentionKind.tag,
          label: t.name,
          ids: [t.id],
          target: NameTarget.tagId,
        ),
      );
    }
    for (final c in centers) {
      entries.add(
        NameEntry(
          kind: MentionKind.center,
          label: c.name,
          ids: [c.id],
          target: NameTarget.centerId,
        ),
      );
    }
    for (final t in trips) {
      entries.add(
        NameEntry(
          kind: MentionKind.trip,
          label: t.name,
          ids: [t.id],
          target: NameTarget.tripId,
        ),
      );
    }
    for (final c in computers) {
      entries.add(
        NameEntry(
          kind: MentionKind.computer,
          label: c.name,
          ids: [c.id],
          target: NameTarget.computerId,
        ),
      );
    }
    // Deduplicate identical (kind, label, identity) rows.
    final seen = <String>{};
    return NameIndex([
      for (final e in entries)
        if (seen.add('${e.kind.name}|${e.label}|${e.identity}')) e,
    ]);
  }
}
