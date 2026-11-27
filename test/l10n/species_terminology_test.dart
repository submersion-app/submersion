import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The app calls the catalog, the per-dive sightings and the browse page
/// "Species". "Marine Life" was the older term and survived on a handful of
/// section headers, the picker title and the Insights tab, which read as a
/// second, separate feature sitting next to the Species page. The dive list
/// filter, the Detailed PDF, two Connections labels and the video labels
/// action followed later: the catalog and species identification cover
/// freshwater animals too, so "marine" no longer fits.
///
/// The safety incident category is not a Species label: it names what caused
/// an injury, not the catalog. It says "Aquatic life" rather than "Marine
/// life" for the same freshwater reason.
void main() {
  List<String> speciesTermLabels(AppLocalizations l10n) => [
    l10n.nav_species,
    l10n.diveLog_detail_section_marineLife,
    l10n.diveLog_edit_section_marineLife,
    l10n.diveLog_edit_noMarineLife,
    l10n.diveLog_speciesPicker_title,
    l10n.diveSites_edit_section_expectedMarineLife,
    l10n.marineLife_siteSection_title,
    l10n.marineLife_siteSection_noSpotted,
    l10n.marineLife_speciesPage_emptyHint,
    l10n.diveDetailSection_sightings_name,
    l10n.settings_manage_species_subtitle,
    l10n.insights_category_marineLife_title,
    l10n.insights_marineLife_appBar_title,
    l10n.insights_marineLife_bestSites_title,
    l10n.diveLog_filter_sectionSpecies,
    l10n.pdf_sectionMarineLife,
    l10n.connections_caption_reef,
    l10n.connections_preset_life,
    l10n.media_labels_action,
    // The same button's tooltips, naming how far analysis has got.
    l10n.media_labels_buttonNotAnalysed,
    l10n.media_labels_buttonAnalysing,
    l10n.media_labels_buttonPartlyAnalysed,
    l10n.media_labels_buttonOutdated,
    l10n.media_labels_buttonAnalysed,
  ];

  /// The wording each locale used for the old "marine life" term. Every entry
  /// is lowercase and matched as a substring.
  const staleTerms = <String, List<String>>{
    'en': ['marine life'],
    'de': ['meeres'],
    'fr': ['marin'],
    'es': ['marin'],
    'it': ['marin'],
    'nl': ['zeeleven', 'onderwaterleven', 'marien'],
    'pt': ['marin'],
    'hu': ['tengeri'],
    'ar': ['البحرية'],
    'he': ['ימי'],
    'zh': ['海洋生物'],
    'ja': ['海洋生物'],
  };

  test('the English species surfaces use the Species term', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.nav_species, 'Species');
    expect(en.diveLog_detail_section_marineLife, 'Species');
    expect(en.diveLog_edit_section_marineLife, 'Species');
    expect(en.diveLog_edit_noMarineLife, 'No species logged');
    expect(en.diveLog_speciesPicker_title, 'Add Species');
    expect(en.diveSites_edit_section_expectedMarineLife, 'Expected Species');
    expect(en.marineLife_siteSection_title, 'Species');
    expect(en.marineLife_siteSection_noSpotted, 'No species spotted yet');
    expect(en.diveDetailSection_sightings_name, 'Species Sightings');
    expect(en.settings_manage_species_subtitle, 'Manage the species catalog');
    expect(en.insights_category_marineLife_title, 'Species');
    expect(en.insights_marineLife_appBar_title, 'Species');
    expect(en.insights_marineLife_bestSites_title, 'Best Sites');
    expect(en.diveLog_filter_sectionSpecies, 'Species');
    expect(en.pdf_sectionMarineLife, 'Species');
    expect(
      en.connections_caption_reef,
      'Sites, species and dive types; a line means they share dives.',
    );
    expect(en.connections_preset_life, 'Sites by species');
    expect(en.media_labels_action, 'Species labels');
  });

  test('the nav label matches the Species page title in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.nav_species,
        l10n.marineLife_speciesPage_title,
        reason: 'nav label and page title disagree in ${locale.languageCode}',
      );
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.languageCode;
    test('no species surface uses the old marine-life term in $code', () {
      final l10n = lookupAppLocalizations(locale);
      final stale = staleTerms[code];
      expect(stale, isNotNull, reason: 'no stale-term list for $code');
      for (final label in speciesTermLabels(l10n)) {
        for (final term in stale!) {
          expect(
            label.toLowerCase(),
            isNot(contains(term)),
            reason: '"$label" still uses "$term"',
          );
        }
      }
    });
  }

  test('the safety incident category says aquatic life', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.incidentCategory_marineLife, 'Aquatic life');
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.languageCode;
    test('the incident category does not say marine in $code', () {
      final label = lookupAppLocalizations(
        locale,
      ).incidentCategory_marineLife.toLowerCase();
      for (final term in staleTerms[code]!) {
        expect(label, isNot(contains(term)), reason: '"$label" says "$term"');
      }
    });
  }
}
