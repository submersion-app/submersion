import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';

/// A new species' sitting (issue #4527, phase 3, plan 11): its seed and the
/// cards laid out open.

/// A new species' starting record under [id]: a custom fish with no name,
/// as the form starts one.
Species newSpeciesSeed({required String id}) =>
    Species(id: id, commonName: '', category: SpeciesCategory.fish);

/// The cards a new species opens with: the header block, then Description.
final List<String> newSpeciesLaidOut = List.unmodifiable([
  SpeciesCardId.header.name,
  SpeciesCardId.description.name,
]);
