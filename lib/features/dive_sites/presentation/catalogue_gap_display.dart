import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How a catalogue pair is put into words: on the review list, in the
/// comparison and on a site's page.

/// The name of [field], as the site editor names it.
String catalogueGapFieldLabel(
  CatalogueGapField field,
  AppLocalizations l10n,
) => switch (field) {
  CatalogueGapField.position => l10n.diveSites_detail_location_gpsCoordinates,
  CatalogueGapField.depth => l10n.diveSites_detail_section_depthRange,
  CatalogueGapField.country => l10n.diveSites_edit_field_country_label,
  CatalogueGapField.region => l10n.diveSites_edit_field_region_label,
  CatalogueGapField.city => l10n.diveSites_edit_field_city_label,
  CatalogueGapField.island => l10n.diveSites_edit_field_island_label,
  CatalogueGapField.bodyOfWater => l10n.diveSites_edit_field_bodyOfWater_label,
  CatalogueGapField.waterType => l10n.diveSites_edit_section_waterType,
  CatalogueGapField.siteTypes => l10n.diveSites_edit_typeTags_typesLabel,
  CatalogueGapField.entry => l10n.diveSites_detail_access_entryMethod,
  CatalogueGapField.difficulty => l10n.diveSites_edit_section_difficultyLevel,
  CatalogueGapField.hazards => l10n.diveSites_edit_hazards_label,
  CatalogueGapField.description => l10n.diveSites_edit_field_description_label,
};

/// What [record] holds for [field], as shown beside the site's empty
/// field: depths in the diver's unit, names in the diver's language.
/// Empty when the record does not carry the field.
String catalogueGapFieldValue(
  CatalogueGapField field,
  CatalogueSite record,
  UnitFormatter units,
  AppLocalizations l10n,
) => switch (field) {
  CatalogueGapField.position => switch (record.location) {
    final at? =>
      '${at.latitude.toStringAsFixed(4)}, ${at.longitude.toStringAsFixed(4)}',
    null => '',
  },
  CatalogueGapField.depth => catalogueDepthRange(record, units) ?? '',
  CatalogueGapField.country => record.country?.trim() ?? '',
  CatalogueGapField.region => record.region?.trim() ?? '',
  CatalogueGapField.city => record.locality?.trim() ?? '',
  CatalogueGapField.island => record.island?.trim() ?? '',
  CatalogueGapField.bodyOfWater => record.bodyOfWater?.trim() ?? '',
  CatalogueGapField.waterType => record.waterType?.localizedName(l10n) ?? '',
  CatalogueGapField.siteTypes => catalogueTypeNames(record, l10n).join(', '),
  CatalogueGapField.entry => catalogueEntryNames(record, l10n).join(', '),
  CatalogueGapField.difficulty => record.difficulty?.localizedName(l10n) ?? '',
  CatalogueGapField.hazards => record.hazards?.trim() ?? '',
  CatalogueGapField.description => record.description?.trim() ?? '',
};

/// The fields a list row only names. Their values are long, or mean
/// little on one line; the comparison shows them in full.
const _namedOnly = {
  CatalogueGapField.position,
  CatalogueGapField.hazards,
  CatalogueGapField.description,
};

/// One line saying what applying [pair] would add: the link first when the
/// site has none, then each offered field, a short value as itself and a
/// long one by its name.
String catalogueGapAddsLine(
  CataloguePair pair,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final items = <String>[
    if (pair.addsLink) l10n.diveSites_gapReview_addsLink,
    for (final field in pair.fields)
      if (_namedOnly.contains(field))
        catalogueGapFieldLabel(field, l10n)
      else
        switch (catalogueGapFieldValue(field, pair.record, units, l10n)) {
          '' => catalogueGapFieldLabel(field, l10n),
          final value => value,
        },
  ];
  return l10n.diveSites_gapReview_adds(items.join(', '));
}
