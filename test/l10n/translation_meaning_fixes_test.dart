import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #2480: meaning errors found while the
/// diacritics sweep (#2283) read the translated ARB files beside English.
///
/// Several of them were English drift rather than mistranslation: the English
/// string gained a clause (Excel export, the + button on the weight presets
/// page, the data sources and narcosis settings) and the translations never
/// followed. Those are checked as invariants across every locale, phrased in
/// terms of each file's own labels so the tests do not pin one wording.
void main() {
  const translated = [
    'ar',
    'de',
    'es',
    'fr',
    'he',
    'hu',
    'it',
    'nl',
    'pt',
    'zh',
  ];

  AppLocalizations l10nFor(String locale) =>
      lookupAppLocalizations(Locale(locale));

  Map<String, dynamic> arb(String locale) =>
      json.decode(
            File(
              p.join('lib', 'l10n', 'arb', 'app_$locale.arb'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('strings the English source outgrew', () {
    for (final locale in translated) {
      test('$locale export help names Excel and the backup page', () {
        final l10n = l10nFor(locale);
        expect(l10n.transfer_export_aboutContent, contains('Excel'));
        expect(
          l10n.transfer_export_aboutContent,
          contains(
            '${l10n.settings_appBar_title} > ${l10n.settings_data_backup}',
          ),
        );
      });

      test('$locale weight presets empty state mentions the + button', () {
        expect(l10nFor(locale).weightPresets_page_empty, contains('+'));
      });
    }

    test('the decompression subtitle lists GF, data sources and narcosis', () {
      final expected = {
        'ar': 'GF، مصادر البيانات والتخدير',
        'de': 'GF, Datenquellen & Narkose',
        'es': 'GF, fuentes de datos y narcosis',
        'fr': 'GF, sources de données et narcose',
        'he': 'GF, מקורות נתונים ונרקוזה',
        'hu': 'GF, adatforrások és narkózis',
        'it': 'GF, fonti dei dati e narcosi',
        'nl': 'GF, gegevensbronnen & narcose',
        'pt': 'GF, fontes de dados e narcose',
        'zh': '梯度因子、数据来源与麻醉',
      };
      for (final entry in expected.entries) {
        expect(
          l10nFor(entry.key).settings_section_decompression_subtitle,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('the file import label says "from file", not auto-detection', () {
      final expected = {
        'ar': 'استيراد بيانات الغوص من ملف',
        'de': 'Tauchdaten aus Datei importieren',
        'es': 'Importar datos de buceo desde un archivo',
        'fr': 'Importer des données de plongée depuis un fichier',
        'he': 'ייבא נתוני צלילה מקובץ',
        'hu': 'Merülési adatok importálása fájlból',
        'it': 'Importa dati di immersione da file',
        'nl': 'Duikgegevens importeren uit bestand',
        'pt': 'Importar dados de mergulho de um arquivo',
        'zh': '从文件导入潜水数据',
      };
      for (final entry in expected.entries) {
        expect(
          l10nFor(entry.key).transfer_import_fileImportSemanticLabel,
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  test('no two different species share a name in any locale', () {
    // The German Golden Mahseer was called Riesenbarbe, the giant barb's
    // name. The catalog seeds a few species twice under different ids (same
    // scientific name), and those rightly share a name, so a collision only
    // counts when the scientific names differ.
    final catalog =
        ((json.decode(
                      File(
                        p.join('assets', 'data', 'species.json'),
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>)['species']
                as List)
            .cast<Map<String, dynamic>>();

    final offenders = <String>[];
    for (final locale in ['en', ...translated]) {
      final l10n = l10nFor(locale);
      final byName = <String, Map<String, String>>{};
      for (final row in catalog) {
        final id = row['id'] as String;
        final name = builtInSpeciesName(l10n, id)!.toLowerCase();
        (byName[name] ??= {})[id] = row['scientificName'] as String;
      }
      byName.forEach((name, rows) {
        if (rows.values.toSet().length > 1) {
          offenders.add('$locale "$name": ${rows.keys.join(', ')}');
        }
      });
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('German', () {
    late AppLocalizations de;
    setUpAll(() => de = l10nFor('de'));

    test('species names are not swapped or duplicated', () {
      expect(de.species_red_bellied_piranha_name, 'Roter Piranha');
      expect(de.species_black_piranha_name, 'Schwarzer Piranha');
      expect(de.species_black_piranha_desc, startsWith('Großer '));
      expect(de.species_golden_mahseer_name, 'Goldener Mahseer');
      expect(de.species_golden_mahseer_name, isNot(de.species_giant_barb_name));
      expect(de.species_smallmouth_bass_name, 'Schwarzbarsch');
      expect(de.species_lingcod_name, 'Lengdorsch');
    });

    test('long press selects, not separates', () {
      expect(
        de.media_diveMediaSection_thumbnailLabel,
        'Foto anzeigen. Lange drücken zum Auswählen',
      );
    });

    test('No Deco agrees with the feminine Deko', () {
      expect(de.insights_profile_deco_noDeco, 'Keine Deko');
    });

    test('the failed photo import verb agrees with its count', () {
      expect(
        de.media_import_failedToImport(1),
        'Foto konnte nicht importiert werden',
      );
      expect(
        de.media_import_failedToImport(2),
        'Fotos konnten nicht importiert werden',
      );
    });

    test('the gas stats help keeps the pressure lane', () {
      expect(
        de.diveLog_edit_excludeFromGasStatsHelp,
        contains('Druckverbrauch-, AMV- und Gasgemisch-Statistiken'),
      );
    });
  });

  group('French', () {
    late AppLocalizations fr;
    setUpAll(() => fr = l10nFor('fr'));

    test('species names', () {
      expect(fr.species_mekong_giant_catfish_name, 'Silure géant du Mékong');
      expect(fr.species_cardinal_tetra_name, 'Néon cardinal');
      expect(fr.species_coontail_name, 'Cornifle immergé');
    });

    test('the plural incident branch uses the plural verb', () {
      expect(
        fr.equipmentCondition_finding_incidentLinked(3),
        '3 incidents mentionnent cet équipement',
      );
    });

    test('oe is written with the ligature, as the rest of the file does', () {
      final offenders = [
        for (final entry in arb('fr').entries)
          if (!entry.key.startsWith('@') &&
              entry.value is String &&
              RegExp(r'\boe(il|uf)').hasMatch(entry.value as String))
            entry.key,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('Dutch', () {
    late AppLocalizations nl;
    setUpAll(() => nl = l10nFor('nl'));

    test('tissue gas exchange uses the Dutch terms', () {
      expect(nl.dive3d_tissue_onGassing, 'Gasopname');
      expect(nl.dive3d_tissue_offGassing, 'Gasafgifte');
    });

    test('species names and descriptions', () {
      expect(nl.species_channel_catfish_name, 'Kanaalmeerval');
      expect(nl.species_largemouth_bass_name, 'Forelbaars');
      expect(
        nl.species_sauger_desc,
        contains(nl.species_walleye_name.toLowerCase()),
      );
      expect(nl.species_sauger_desc, isNot(contains('walleye')));
    });

    test('grammar in species descriptions', () {
      expect(nl.species_brain_coral_desc, isNot(contains('een hersenen')));
      expect(nl.species_nile_perch_desc, contains('een zwartomrand oog'));
      expect(nl.species_black_caiman_desc, startsWith('Het grootste roofdier'));
      expect(nl.species_muskrat_desc, startsWith('Ratgroot bruin knaagdier'));
      expect(nl.species_sea_spider_desc, startsWith('Tere, langpotige'));
      expect(
        nl.species_squat_lobster_desc,
        startsWith('Piepkleine roze-paarse'),
      );
      expect(nl.species_blue_groper_desc, contains('Oost-Australië'));
    });
  });

  group('Hungarian', () {
    late AppLocalizations hu;
    setUpAll(() => hu = l10nFor('hu'));

    test('SCR supply gas is tápgáz', () {
      expect(hu.gas_scrEan40_description, 'SCR tápgáz - 40% O2');
      expect(hu.gas_scrEan50_description, 'SCR tápgáz - 50% O2');
      expect(hu.gas_scrEan60_description, 'SCR tápgáz - 60% O2');
    });

    test('the deco calculator computes no-deco limits', () {
      expect(hu.planning_card_decoCalculator_description, contains('nullidő'));
    });

    test('cached tiles are gyorsítótárazott', () {
      expect(
        hu.maps_offline_deleteRegionMessage('x', 3, '1 MB'),
        contains('gyorsítótárazott'),
      );
      expect(
        hu.maps_offline_clearAllCacheMessage,
        contains('gyorsítótárazott'),
      );
    });

    test('import label recognises, not walls', () {
      expect(
        hu.transfer_import_fileImportSemanticLabel,
        isNot(contains('falismer')),
      );
    });

    test('buddy is Búvártárs everywhere, not the English word', () {
      // Only placeholder names such as {buddyName}; a broader pattern would
      // also erase plural branch bodies like =1{buddy}.
      final placeholder = RegExp(r'\{buddy[A-Z]\w*\}');
      final offenders = <String>[];
      arb('hu').forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        final text = value.replaceAll(placeholder, '');
        if (RegExp('buddy', caseSensitive: false).hasMatch(text)) {
          offenders.add('$key = $value');
        }
      });
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      expect(hu.nav_buddies, 'Búvártársak');
      expect(hu.diveLog_detail_buddyCount(2), '2 búvártárs');
    });

    test('species descriptions', () {
      for (final desc in [
        hu.species_mahi_mahi_desc,
        hu.species_silky_shark_desc,
        hu.species_yellowfin_tuna_desc,
      ]) {
        expect(desc, isNot(contains('part menti')));
        expect(desc, contains('parttól távoli'));
      }
      expect(hu.species_pygmy_seahorse_desc, isNot(contains('gazdanövény')));
      expect(hu.species_candy_crab_desc, isNot(contains('gazdanövény')));
      expect(hu.species_spangled_perch_desc, isNot(contains('víznyelő')));
    });
  });
}
