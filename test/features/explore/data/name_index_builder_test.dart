import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/explore/data/name_index_builder.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('builds place, site, species and gear entries from entity lists', () {
    final now = DateTime(2026, 1, 1);
    final index = NameIndexBuilder.fromEntities(
      sites: const [
        DiveSite(
          id: 's1',
          name: 'Salt Pier',
          country: 'Bonaire',
          region: 'Caribbean Netherlands',
        ),
        DiveSite(
          id: 's2',
          name: '1000 Steps',
          country: 'Bonaire',
          island: 'Bonaire',
        ),
      ],
      species: const [
        Species(
          id: 'sp_green_turtle',
          commonName: 'Green Turtle',
          scientificName: 'Chelonia mydas',
          category: SpeciesCategory.turtle,
          isBuiltIn: true,
        ),
      ],
      equipment: const [
        EquipmentItem(
          id: 'g1',
          name: 'MTX-R',
          type: EquipmentType.firstStage,
          brand: 'Apeks',
          model: 'MTX-R',
        ),
      ],
      buddies: [
        Buddy(id: 'b1', name: 'Sarah Jones', createdAt: now, updatedAt: now),
      ],
      legacyBuddyNames: const ['Old Pal'],
      tags: const [],
      centers: const [],
      trips: const [],
      computers: const [],
      l10n: AppLocalizationsEn(),
    );

    NameEntry one(MentionKind k, String label) =>
        index.forKind(k).firstWhere((e) => e.label == label);

    expect(
      one(MentionKind.place, 'Bonaire').ids,
      unorderedEquals(['s1', 's2']),
    );
    expect(one(MentionKind.place, 'Bonaire').rank, 0);
    expect(one(MentionKind.place, 'Caribbean Netherlands').rank, 1);
    expect(one(MentionKind.site, 'Salt Pier').ids, ['s1']);
    expect(
      index.forKind(MentionKind.species).map((e) => e.label),
      containsAll(['Green Turtle', 'Chelonia mydas']),
    );
    expect(one(MentionKind.gear, 'MTX-R').target, NameTarget.equipmentId);
    expect(one(MentionKind.gear, 'Apeks MTX-R').rank, 1);
    expect(
      index
          .forKind(MentionKind.gear)
          .where((e) => e.target == NameTarget.attrChoice)
          .map((e) => e.attrChoice),
      contains('trilaminate'),
    );
    expect(
      one(MentionKind.buddy, 'Old Pal').target,
      NameTarget.legacyBuddyName,
    );
  });

  test('tags, centers, trips and computers each get an entry', () {
    final now = DateTime(2026, 1, 1);
    final index = NameIndexBuilder.fromEntities(
      sites: const [],
      species: const [],
      equipment: const [],
      buddies: const [],
      legacyBuddyNames: const [],
      tags: [Tag(id: 't1', name: 'Night', createdAt: now, updatedAt: now)],
      centers: [
        DiveCenter(
          id: 'c1',
          name: 'Buddy Dive',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      trips: [
        Trip(
          id: 'tr1',
          name: 'Bonaire 2025',
          startDate: now,
          endDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      computers: [
        DiveComputer(id: 'dc1', name: 'Perdix', createdAt: now, updatedAt: now),
      ],
      l10n: AppLocalizationsEn(),
    );

    ({MentionKind kind, NameTarget target, List<String> ids}) only(
      MentionKind k,
    ) {
      final e = index.forKind(k).single;
      return (kind: e.kind, target: e.target, ids: e.ids);
    }

    expect(only(MentionKind.tag).target, NameTarget.tagId);
    expect(only(MentionKind.tag).ids, ['t1']);
    expect(only(MentionKind.center).target, NameTarget.centerId);
    expect(only(MentionKind.trip).target, NameTarget.tripId);
    expect(only(MentionKind.computer).target, NameTarget.computerId);
  });

  test('a site with no place fields contributes no place entry', () {
    final index = NameIndexBuilder.fromEntities(
      sites: const [DiveSite(id: 's1', name: 'House Reef', country: '  ')],
      species: const [
        Species(
          id: 'custom-uuid',
          commonName: 'Odd Fish',
          category: SpeciesCategory.fish,
        ),
      ],
      equipment: const [
        // Brand and model repeating the name adds no second label.
        EquipmentItem(
          id: 'g1',
          name: 'Perdix',
          type: EquipmentType.computer,
          brand: 'Perdix',
        ),
      ],
      buddies: const [],
      legacyBuddyNames: const [],
      tags: const [],
      centers: const [],
      trips: const [],
      computers: const [],
      l10n: AppLocalizationsEn(),
    );

    expect(index.forKind(MentionKind.place), isEmpty);
    expect(index.forKind(MentionKind.site).single.label, 'House Reef');
    // A custom species has no localized name and no scientific name, so it
    // contributes its stored name alone.
    expect(index.forKind(MentionKind.species).map((e) => e.label), [
      'Odd Fish',
    ]);
    expect(
      index
          .forKind(MentionKind.gear)
          .where((e) => e.target == NameTarget.equipmentId)
          .map((e) => e.label),
      ['Perdix'],
    );
  });
}
