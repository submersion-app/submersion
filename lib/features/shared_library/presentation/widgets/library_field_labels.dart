import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The localized label of a shared site library document field (issue #2567):
/// the site's own column labels, and the section names for its lists.
String libraryFieldLabel(AppLocalizations l10n, String field) =>
    switch (field) {
      'siteTypes' => l10n.diveSites_edit_typeTags_typesLabel,
      'tags' => l10n.diveSites_edit_typeTags_tagsLabel,
      'species' => l10n.marineLife_siteSection_expectedSpecies,
      'features' => l10n.siteFeature_sectionTitle,
      _ => conflictFieldFor('diveSites', field).label(l10n),
    };

/// A document value as the app shows it elsewhere: depths and altitude in
/// the diver's units, enums by name, lists by their entries' names.
String libraryFieldValue(
  AppLocalizations l10n,
  UnitFormatter units,
  String field,
  Object? value,
) {
  if (value is List) {
    return value
        .map((v) => v is Map ? (v['name'] ?? v['type'] ?? '').toString() : '$v')
        .join(', ');
  }
  return formatConflictValue(
    l10n: l10n,
    units: units,
    field: conflictFieldFor('diveSites', field),
    value: value,
  );
}
