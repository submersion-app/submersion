import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/services/app_tag_guards.dart';

/// Whether rejecting a tag the app applied may take the sighting or species
/// it created with it (issue #4727): only when nothing else uses it and the
/// diver has not changed it.
void main() {
  // As SpeciesTaggingService creates one for a tag: seen, count 1, no notes.
  const created = Sighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp1',
    speciesName: 'Queen Parrotfish',
  );

  group('mayRemoveCreatedSighting', () {
    test('removes a sighting nothing else uses and nobody changed', () {
      expect(
        mayRemoveCreatedSighting(sighting: created, otherTagsPointingAtIt: 0),
        isTrue,
      );
    });

    test('keeps a sighting another tag points at', () {
      expect(
        mayRemoveCreatedSighting(sighting: created, otherTagsPointingAtIt: 1),
        isFalse,
      );
    });

    test('keeps a sighting whose count changed', () {
      expect(
        mayRemoveCreatedSighting(
          sighting: created.copyWith(
            abundance: SightingAbundance.exact,
            count: 3,
          ),
          otherTagsPointingAtIt: 0,
        ),
        isFalse,
      );
    });

    test('keeps a sighting whose abundance changed', () {
      expect(
        mayRemoveCreatedSighting(
          sighting: created.copyWith(abundance: SightingAbundance.many),
          otherTagsPointingAtIt: 0,
        ),
        isFalse,
      );
    });

    test('keeps a sighting with notes', () {
      expect(
        mayRemoveCreatedSighting(
          sighting: created.copyWith(notes: 'at the cleaning station'),
          otherTagsPointingAtIt: 0,
        ),
        isFalse,
      );
    });
  });

  group('mayRemoveCreatedSpecies', () {
    const species = Species(
      id: 'sp1',
      commonName: 'Creole Wrasse',
      scientificName: 'Clepticus parrae',
      category: SpeciesCategory.fish,
    );
    final tagHlc = const Hlc(1700, 0, 'dev-a').toString();
    final before = const Hlc(1600, 0, 'dev-a').toString();
    final after = const Hlc(1800, 0, 'dev-b').toString();

    test('removes a species unused and unwritten since the tag', () {
      expect(
        mayRemoveCreatedSpecies(
          species: species,
          speciesHlc: before,
          tagHlc: tagHlc,
          inUseElsewhere: false,
        ),
        isTrue,
      );
    });

    test('keeps a species used elsewhere', () {
      expect(
        mayRemoveCreatedSpecies(
          species: species,
          speciesHlc: before,
          tagHlc: tagHlc,
          inUseElsewhere: true,
        ),
        isFalse,
      );
    });

    test('keeps a species written after the tag', () {
      expect(
        mayRemoveCreatedSpecies(
          species: species,
          speciesHlc: after,
          tagHlc: tagHlc,
          inUseElsewhere: false,
        ),
        isFalse,
      );
    });

    test('keeps a built-in species', () {
      expect(
        mayRemoveCreatedSpecies(
          species: species.copyWith(isBuiltIn: true),
          speciesHlc: before,
          tagHlc: tagHlc,
          inUseElsewhere: false,
        ),
        isFalse,
      );
    });

    test('a species with no clock is not known to be edited', () {
      expect(
        mayRemoveCreatedSpecies(
          species: species,
          speciesHlc: null,
          tagHlc: tagHlc,
          inUseElsewhere: false,
        ),
        isTrue,
      );
    });
  });
}
