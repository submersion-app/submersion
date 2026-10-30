import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'seed_context.dart';

/// Tags, species, sites and dive centres: every place comes from the app's
/// public catalogues, classified by its destination.
class PlacesSeeder implements DemoSeeder {
  @override
  String get name => 'tags, species, sites and centres';

  static const _tags = <String, (String, Set<TagScope>)>{
    'Favourite': ('#E53935', {TagScope.dives, TagScope.sites, TagScope.media}),
    'Photo': ('#1E88E5', {TagScope.dives, TagScope.media}),
    'Training': ('#43A047', {TagScope.dives, TagScope.documents}),
    'Wreck': ('#6D4C41', {TagScope.dives, TagScope.sites}),
    'Current': ('#00897B', {TagScope.dives, TagScope.sites}),
    'Travel kit': ('#8E24AA', {TagScope.equipment}),
    'Needs service': ('#FB8C00', {TagScope.equipment}),
  };

  static const _tankNotes = [
    'Valve was stiff; ask for another.',
    'Fine.',
    'Filled to 200 bar every morning.',
    'O-ring needed changing on the second day.',
    'Nitrox on request, analysed on the dock.',
    'Tanks a little low; check before kitting up.',
  ];
  static const _leadNotes = [
    'Two kilos less than at home with the aluminium.',
    'Soft weights, plenty of them.',
    'Only block weights; bring a pocket belt.',
    'One kilo less in the 3 mm.',
  ];
  static const _regulatorNotes = [
    'Breathed well.',
    'Octopus breathed wet; bring my own next time.',
    'Old but serviced; fine for the shallow reef.',
  ];

  /// The demo's tag names, for the privacy check's allow list.
  static Iterable<String> get tagNames => _tags.keys;

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final created = ctx.plan.dives.first.start;
    final tags = TagRepository();
    for (final MapEntry(key: name, value: (color, scopes)) in _tags.entries) {
      final id = 'demo-tag-${name.toLowerCase().replaceAll(' ', '-')}';
      await tags.createTag(
        Tag(
          id: id,
          name: name,
          diverId: DemoSeedContext.diverId,
          colorHex: color,
          scopes: scopes,
          createdAt: created,
          updatedAt: created,
        ),
      );
      ctx.tags[name] = id;
    }

    final species = SpeciesRepository();
    await species.seedBuiltInSpecies();
    for (final s in await species.getAllSpecies()) {
      ctx.species[s.commonName] = s.id;
    }

    await SiteTypeRepository().createSiteType(
      SiteTypeEntity(
        id: 'demo-site-type-lake-platform',
        name: 'Training platform',
        diverId: DemoSeedContext.diverId,
        createdAt: created,
        updatedAt: created,
      ),
    );

    final destOfSite = <String, Destination>{
      for (final d in ctx.plan.dives) d.siteId: d.destination,
    };
    final sites = SiteRepository();
    final features = SiteFeatureRepository();
    var i = 0;
    for (final s in ctx.plan.sites) {
      final dest = destOfSite[s.id]!;
      final types = destinationSiteTypes[dest.key]!;
      final type = types[i % types.length];
      final deep = dest.key == 'med' || type == 'wall';
      await sites.createSite(
        DiveSite(
          id: ctx.siteId(s.id),
          diverId: DemoSeedContext.diverId,
          name: s.name,
          description: s.description ?? '',
          location: GeoPoint(s.latitude, s.longitude),
          maxDepth: deep
              ? 40 + (i % 4) * 5.0
              : (dest.freshwater ? 18 : 28) + (i % 3) * 2.0,
          minDepth: dest.freshwater ? 2 : 5,
          difficulty: deep
              ? SiteDifficulty.advanced
              : SiteDifficulty.intermediate,
          waterType: dest.freshwater ? WaterType.fresh : WaterType.salt,
          country: s.country,
          region: s.region,
          rating: 3.0 + (i % 3),
          entryMethods: dest.freshwater
              ? const [EntryMethod.shore]
              : const [EntryMethod.boat, EntryMethod.backRoll],
        ),
        classification: SiteClassification(
          typeIds: [
            type,
            if (dest.freshwater && i == 0) 'demo-site-type-lake-platform',
          ],
          tagIds: [
            if (type == 'wreck') ctx.tags['Wreck']!,
            if (i % 5 == 0) ctx.tags['Favourite']!,
            if (type == 'wall') ctx.tags['Current']!,
          ],
        ),
      );
      if (i % 3 == 0) {
        await features.addFeature(
          siteId: ctx.siteId(s.id),
          typeName: dest.freshwater ? 'Entry point' : 'Mooring',
          latitude: s.latitude + 0.0003,
          longitude: s.longitude + 0.0002,
          depthMeters: dest.freshwater ? 0 : 6,
          name: dest.freshwater ? 'Main entry' : 'Mooring line',
        );
      }
      for (final common in destinationSpecies[dest.key]!.take(3)) {
        final id = ctx.species[common];
        if (id != null) {
          await species.addExpectedSpecies(
            siteId: ctx.siteId(s.id),
            speciesId: id,
          );
        }
      }
      i++;
    }

    // The partner profile sees the home sites; one far-away site is hidden
    // from them.
    final homeSites = ctx.plan.sites.where(
      (s) => destOfSite[s.id]!.key == 'home',
    );
    final shares = ItemSharesRepository();
    for (final s in homeSites.take(3)) {
      await shares.setSharing(
        SharedItemKind.site,
        ctx.siteId(s.id),
        const ItemSharing(
          everyone: false,
          profileIds: {DemoSeedContext.partnerId},
        ),
        actingDiverId: DemoSeedContext.diverId,
      );
    }
    final away = ctx.plan.sites.firstWhere(
      (s) => destOfSite[s.id]!.key != 'home',
    );
    // Shared with every profile, then hidden by the partner: hiding only
    // applies to an item someone else shared.
    await shares.setSharing(
      SharedItemKind.site,
      ctx.siteId(away.id),
      const ItemSharing(everyone: true, profileIds: {}),
      actingDiverId: DemoSeedContext.diverId,
    );
    await ProfileHidesRepository().hide(
      SharedItemKind.site,
      ctx.siteId(away.id),
      DemoSeedContext.partnerId,
    );

    final centers = DiveCenterRepository();
    final notes = DiveCenterGearNoteRepository();
    var c = 0;
    for (final center in ctx.plan.centers) {
      final id = ctx.centerId(center.id);
      await centers.createDiveCenter(
        DiveCenter(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: center.name,
          country: center.country,
          latitude: center.latitude,
          longitude: center.longitude,
          affiliations: const ['PADI', 'SSI'],
          rating: 4.0 + (c % 2),
          createdAt: created,
          updatedAt: created,
        ),
      );
      // What was rented here: cylinders and lead every time, the
      // regulator too before the diver owned one.
      final here = [
        for (final d in ctx.plan.dives)
          if (d.centerId == center.id) d,
      ];
      final first = here.isEmpty ? created : here.first.start;
      final ownReg = ctx.plan.milestones[StoryMilestone.ownRegulator]!;
      final rentedRegulator = here.any((d) => d.number < ownReg);
      var k = 0;
      Future<void> note(
        EquipmentType type,
        String label,
        RentalVerdict verdict,
        String text, {
        double? lead,
        double? litres,
      }) => notes.create(
        DiveCenterGearNote(
          id: 'demo-gear-note-$c-${k++}',
          diveCenterId: id,
          gearType: type,
          label: label,
          verdict: verdict,
          leadAdjustmentKg: lead,
          volumeLiters: litres,
          note: text,
          notedAt: first,
          createdAt: first,
          updatedAt: first,
        ),
      );
      await note(
        EquipmentType.tank,
        'Rental 12 L aluminium',
        c % 3 == 0 ? RentalVerdict.avoid : RentalVerdict.worked,
        _tankNotes[c % _tankNotes.length],
        litres: 11.1,
      );
      await note(
        EquipmentType.weights,
        'Lead',
        RentalVerdict.worked,
        _leadNotes[c % _leadNotes.length],
        lead: -2,
      );
      if (rentedRegulator) {
        await note(
          EquipmentType.regulator,
          'Rental regulator',
          c.isEven ? RentalVerdict.worked : RentalVerdict.avoid,
          _regulatorNotes[c % _regulatorNotes.length],
        );
      }
      c++;
    }
  }
}
