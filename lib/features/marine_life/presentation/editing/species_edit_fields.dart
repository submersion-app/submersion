import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The species page's values a sitting edits (issue #4527, phase 3). Each
/// edits the stored text, which for a built-in species is the catalogue's
/// English until changed: the page shows a translation only while a value
/// still equals the catalogue's (`species_display.dart`).

final String _header = SpeciesCardId.header.name;
final String _description = SpeciesCardId.description.name;

/// [s] with the given values, every other one kept. [Species.copyWith]
/// cannot clear a value, so the fields build the species whole, as the
/// old edit form's save did.
Species _with(
  Species s, {
  String? commonName,
  Object? scientificName = _keep,
  SpeciesCategory? category,
  Object? taxonomyClass = _keep,
  Object? description = _keep,
}) => Species(
  id: s.id,
  commonName: commonName ?? s.commonName,
  scientificName: identical(scientificName, _keep)
      ? s.scientificName
      : scientificName as String?,
  category: category ?? s.category,
  taxonomyClass: identical(taxonomyClass, _keep)
      ? s.taxonomyClass
      : taxonomyClass as String?,
  description: identical(description, _keep)
      ? s.description
      : description as String?,
  photoPath: s.photoPath,
  isBuiltIn: s.isBuiltIn,
);

const Object _keep = Object();

/// A blank optional value is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Required: a sitting with it blank cannot be saved (the header card's
/// check).
final speciesCommonNameField = EditField<Species, String>(
  id: 'commonName',
  cardId: _header,
  read: (s) => s.commonName,
  write: (s, v) => _with(s, commonName: v.trim()),
  // Spaces around the name are not a change: the save trims them.
  equals: (a, b) => a.trim() == b.trim(),
);

final speciesScientificNameField = EditField<Species, String?>(
  id: 'scientificName',
  cardId: _header,
  read: (s) => s.scientificName,
  write: (s, v) => _with(s, scientificName: _orNone(v)),
  equals: (a, b) => _orNone(a) == _orNone(b),
);

final speciesCategoryField = EditField<Species, SpeciesCategory>(
  id: 'category',
  cardId: _header,
  read: (s) => s.category,
  write: (s, v) => _with(s, category: v),
);

final speciesTaxonomyClassField = EditField<Species, String?>(
  id: 'taxonomyClass',
  cardId: _header,
  read: (s) => s.taxonomyClass,
  write: (s, v) => _with(s, taxonomyClass: _orNone(v)),
  equals: (a, b) => _orNone(a) == _orNone(b),
);

final speciesDescriptionField = EditField<Species, String?>(
  id: 'description',
  cardId: _description,
  read: (s) => s.description,
  write: (s, v) => _with(s, description: _orNone(v)),
  equals: (a, b) => _orNone(a) == _orNone(b),
);
