import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_description_lookup.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Display-time localization for species, following the pattern
/// `dive_type_display.dart` set for seeded built-in reference data.
///
/// Nothing here touches what is stored: the `species` table keeps its English
/// `common_name` and `description` because built-in rows are excluded from
/// sync and the stored name is what UDDF export writes out.

extension SpeciesCategoryDisplay on SpeciesCategory {
  /// Localized label for this category.
  ///
  /// `SpeciesCategory.displayName` is a hardcoded English literal baked into
  /// the enum, so every filter chip, dropdown and section header rendered it
  /// in English under a translated locale. The `enum_speciesCategory_*` keys
  /// already ship translated in every locale.
  String localizedName(AppLocalizations l10n) => switch (this) {
    SpeciesCategory.fish => l10n.enum_speciesCategory_fish,
    SpeciesCategory.shark => l10n.enum_speciesCategory_shark,
    SpeciesCategory.ray => l10n.enum_speciesCategory_ray,
    SpeciesCategory.mammal => l10n.enum_speciesCategory_mammal,
    SpeciesCategory.turtle => l10n.enum_speciesCategory_turtle,
    SpeciesCategory.invertebrate => l10n.enum_speciesCategory_invertebrate,
    SpeciesCategory.coral => l10n.enum_speciesCategory_coral,
    SpeciesCategory.plant => l10n.enum_speciesCategory_plant,
    SpeciesCategory.other => l10n.enum_speciesCategory_other,
  };
}

extension SpeciesDisplay on Species {
  /// Localized common name for a built-in species; the stored name for a
  /// custom one.
  ///
  /// The [isBuiltIn] guard matters: a diver's own species must render the
  /// text they typed, never a translation.
  String localizedCommonName(AppLocalizations l10n) =>
      isBuiltIn ? (builtInSpeciesName(l10n, id) ?? commonName) : commonName;

  /// Localized description for a built-in species; the stored description for
  /// a custom one. Null when the row has no description at all.
  String? localizedDescription(AppLocalizations l10n) => isBuiltIn
      ? (builtInSpeciesDescription(l10n, id) ?? description)
      : description;
}

/// Localized name for a species reachable only by id and denormalized name.
///
/// Sightings, expected-species entries and site summaries all carry a copy of
/// the species name rather than the [Species] row, so there is no `isBuiltIn`
/// flag to consult. Resolving on the id is safe anyway: custom species are
/// created with a UUID v4 (`SpeciesRepository.createSpecies`), which can never
/// match an `sp_` seed slug, so a custom row always falls through to
/// [storedName].
String localizedSpeciesName(
  AppLocalizations l10n,
  String id,
  String storedName,
) => builtInSpeciesName(l10n, id) ?? storedName;

/// Repository search hits plus catalog rows whose *localized* name matches.
///
/// `SpeciesRepository.searchSpecies` matches `common_name`,
/// `scientific_name` and `taxonomy_class`, and the first of those stays
/// English for every built-in species. Once the list renders translated names
/// a German diver searching "Walhai" would otherwise get an empty result --
/// and, in the dive-log picker, an offer to create a duplicate custom
/// species. Folding the localized matches in keeps search consistent with
/// what is on screen.
///
/// Ordered by category then localized name so the grouped sections keep the
/// shape `searchSpecies` produced (`ORDER BY category, common_name`).
List<Species> withLocalizedSpeciesMatches({
  required List<Species> results,
  required List<Species> catalog,
  required String query,
  required AppLocalizations l10n,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return results;

  final seen = results.map((s) => s.id).toSet();
  final merged = [
    ...results,
    ...catalog.where(
      (s) =>
          !seen.contains(s.id) &&
          s.localizedCommonName(l10n).toLowerCase().contains(needle),
    ),
  ];
  merged.sort((a, b) {
    final byCategory = a.category.index.compareTo(b.category.index);
    if (byCategory != 0) return byCategory;
    return a
        .localizedCommonName(l10n)
        .toLowerCase()
        .compareTo(b.localizedCommonName(l10n).toLowerCase());
  });
  return merged;
}
