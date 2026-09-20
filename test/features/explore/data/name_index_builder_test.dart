import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/explore/data/name_index_builder.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
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
}
