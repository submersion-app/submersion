import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Spanish and Portuguese ARBs against losing their diacritics
/// again, as issue #2235 found: `Pais` for `País`, `Configuracoes` for
/// `Configurações`, `Descompresion` for `Descompresión`.
///
/// Three checks run over each file:
///
/// 1. **The twin scan.** A file that spells the same word both ways
///    contradicts itself, so any word written without its accents while the
///    accented spelling appears elsewhere in that same file is reported. That
///    is how the breakage looked: `Configuración` sat two lines from
///    `Descompresion`. It needs no vocabulary of its own, so it keeps working
///    as strings are added.
/// 2. **Portuguese clitics.** An `-ar`/`-er` infinitive before `-lo`/`-la`
///    loses its r and takes the accent, so `descartá-las` is right and
///    `descarta-las` is not. `-ir` verbs take none (`abri-lo`).
/// 3. **Spanish preterites.** `Se cambio a {name}` and `La descarga fallo` are
///    missing the accent that makes them past tense. The twin scan cannot see
///    these on its own, because `cambio` and `fallo` are also real nouns.
///
/// [homographs] lists the pairs where both spellings are real words. An entry
/// names the keys the bare spelling may appear in whenever that list is short
/// enough to be worth pinning; a word-wide entry is for the function words and
/// abbreviations where a key list would run to dozens of entries and rot.
void main() {
  const homographs = <String, Map<String, _Homograph>>{
    'es': {
      // Function words and abbreviations: too common to pin to keys.
      'el': _Homograph('the article el, and the pronoun él'),
      'que': _Homograph('the relative que, and the interrogative qué'),
      'una': _Homograph('the article una, and uña, a claw'),
      'este': _Homograph('the demonstrative este, and the subjunctive esté'),
      'esta': _Homograph('the demonstrative esta, and the verb está'),
      'estas': _Homograph('the demonstrative estas, and the verb estás'),
      'como': _Homograph('como meaning as, and the interrogative cómo'),
      'cuando': _Homograph('the relative cuando, and the interrogative cuándo'),
      'donde': _Homograph('the relative donde, and the interrogative dónde'),
      'si': _Homograph('the conditional si, and sí meaning yes'),
      'min': _Homograph('min, the minutes unit, and mín. for mínimo'),
      'max': _Homograph('Max in untranslated labels, and máx. for máximo'),
      'registro': _Homograph('the noun registro, and the past tense registró'),
      'cambio': _Homograph(
        'the noun cambio, and the past tense cambió; the verb reading is '
        'caught by the preterite check below rather than by a key list',
      ),
      'completo': _Homograph(
        'the adjective completo, and the past tense completó',
      ),
      // Narrow enough to pin: the bare spelling belongs to these keys only.
      'fallo': _Homograph(
        'the noun fallo, and the past tense falló',
        keys: {
          'divePlanner_field_bailoutGasHint',
          'equipmentObservation_tag_switchFault',
          'equipmentObservation_tag_screenFault',
          'equipmentObservation_tag_connectionFault',
          'equipmentObservation_tag_solenoidFault',
          'equipmentObservation_tag_propFault',
          'startup_engineUnavailable_guidance',
        },
      ),
      'paso': _Homograph(
        'the noun paso, and the past tense pasó',
        keys: {
          'enum_entryMethod_giantStride',
          'universalImport_summary_noticeColumnsNotImportedBody',
          'universalImport_error_unreadableDatesHint',
          'diveImport_healthkit_accessGrantedBody',
          'startup_migrating_progress',
          'backup_operation_upgrading',
        },
      ),
      'reemplazo': _Homograph(
        'the noun reemplazo, and the past tense reemplazó',
        keys: {
          'enum_serviceType_replacement',
          'settings_cloudSync_result_noReplacementToRebuild',
          'settings_cloudSync_result_noReplacementMarker',
        },
      ),
      'continua': _Homograph(
        'the adjective continua, and the verb continúa',
        keys: {
          'diveLog_combine_longSurfaceWarning',
          'diveLog_combine_previewIntro',
          'species_ruffe_desc',
        },
      ),
      'comenzara': _Homograph(
        'the past subjunctive comenzara, and the future comenzará',
        keys: {'diveComputer_download_discoveryStalled'},
      ),
      'terminara': _Homograph(
        'the past subjunctive terminara, and the future terminará',
        keys: {'startup_error_body'},
      ),
      'master': _Homograph(
        'Dive Master, a label kept in English, and máster',
        keys: {'diveLog_detail_label_diveMaster'},
      ),
      'cardiaca': _Homograph(
        'the RAE accepts cardiaca beside cardíaca',
        keys: {
          'settings_appearance_metric_heartRate',
          'transfer_computers_aboutContent',
          'diveImport_healthkit_dataUsage',
          'settings_dataSources_appleHealth_dataTypeHeartRate',
        },
      ),
      'video': _Homograph(
        'video in Latin America, vídeo in Spain',
        keys: {
          'media_diveMediaSection_addTooltip',
          'media_diveMediaSection_title',
          'media_photoViewer_failedToLoadVideo',
          'media_photoViewer_playPauseVideoLabel',
          'media_photoViewer_seekVideoLabel',
          'media_photoViewer_videoFileNotFound',
          'media_photoViewer_videoNotLinked',
        },
      ),
      'videos': _Homograph(
        'video in Latin America, vídeo in Spain',
        keys: {
          'diveDetailSection_media_description',
          'settings_mediaStorage_entry_subtitle',
        },
      ),
    },
    'pt': {
      'a': _Homograph('the article a, and the contraction à'),
      'as': _Homograph('the article as, and the contraction às'),
      'da': _Homograph('the contraction da, and the verb dá'),
      'de': _Homograph('the preposition de, and the imperative dê'),
      'e': _Homograph('the conjunction e, and the verb é'),
      'esta': _Homograph('the demonstrative esta, and the verb está'),
      'la': _Homograph('the pronoun suffix -la, and lá meaning there'),
      'tem': _Homograph('the singular tem, and the plural têm'),
      'pode': _Homograph('the present pode, and the past pôde'),
      'min': _Homograph('min, the minutes unit, and mín. for mínimo'),
      'max': _Homograph('Max in untranslated labels, and máx. for máximo'),
      'oxigenio': _Homograph(
        'oxigénio and oxigênio both appear in this file; the variant is a '
        'translation decision, see issue #2235',
      ),
      'nitrogenio': _Homograph(
        'nitrogénio and nitrogênio both appear; see #2235',
      ),
      'faca': _Homograph(
        'faca, a knife, and faça, the subjunctive of fazer',
        keys: {
          'enum_equipmentType_knife',
          'species_electric_eel_desc',
          'species_clown_knifefish_name',
        },
      ),
      'mares': _Homograph(
        'mares, seas, and marés, tides',
        keys: {
          'diveComputer_list_helpBrandsList',
          'diveLog_detail_tideCalculated',
          'transfer_computers_aboutContent',
          'species_smooth_hammerhead_shark_desc',
          'species_pilot_whale_desc',
          'species_loggerhead_sea_turtle_desc',
        },
      ),
      'media': _Homograph(
        'media, the library, and média, an average',
        keys: {'media_diveMediaSection_unlinkSelectedContent'},
      ),
      'analise': _Homograph(
        'the imperative analise, and the noun análise',
        keys: {'dataQuality_empty_subtitle'},
      ),
      'continua': _Homograph(
        'the verb continua, and the adjective contínua',
        keys: {
          'surfaceInterval_result_beyondHorizon',
          'startup_interruptedRestore_bodyWithDate',
          'startup_interruptedRestore_body',
        },
      ),
      'habitat': _Homograph(
        'habitat and hábitat are both current',
        keys: {
          'species_flatback_sea_turtle_desc',
          'species_staghorn_coral_desc',
          'species_eelgrass_desc',
        },
      ),
      'vem': _Homograph(
        'the singular vem, and the plural vêm',
        keys: {'settings_media_provenanceBadgesSubtitle'},
      ),
      'le': _Homograph(
        'Bluetooth LE, and the verb lê',
        keys: {
          'diveComputer_list_helpBluetooth',
          'diveImport_healthkit_dataUsage',
          'diveComputer_connectionType_ble',
        },
      ),
      'so': _Homograph(
        'so in an untranslated sentence, and só meaning only',
        keys: {'diveLog_whatIf_engineNote'},
      ),
    },
  };

  /// Values that are deliberately still English. Accenting a Spanish or
  /// Portuguese word inside one of them would be wrong.
  const untranslated = <String, Set<String>>{
    'es': {
      'statistics_category_overview_subtitle',
      'transfer_computers_appleWatchSubtitle',
    },
    'pt': {
      'diveLog_edit_customFieldKeyHint',
      'diveLog_rangeStats_label_gasConsumed',
      'divePlanner_gasOptions_title',
      'diveLog_whatIf_engineNote',
    },
  };

  Map<String, String> readArb(String locale) {
    final arb =
        jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@') &&
            entry.value is String &&
            !untranslated[locale]!.contains(entry.key))
          entry.key: entry.value as String,
    };
  }

  for (final locale in homographs.keys) {
    test('app_$locale.arb spells no word both with and without its accents', () {
      final accentedForms = <String, Set<String>>{};
      final bareUses = <String, List<String>>{};
      readArb(locale).forEach((key, value) {
        for (final token in messageWords(value.replaceAll(_clitic, ' '))) {
          // Short all-caps runs are acronyms and hardware labels: GAS is what
          // the Perdix overlay prints, LE is Bluetooth LE, EUA is the USA.
          if (token.length < 4 && token == token.toUpperCase()) continue;
          final lower = token.toLowerCase();
          final bare = withoutAccents(lower);
          if (bare == lower) {
            bareUses.putIfAbsent(lower, () => <String>[]).add(key);
          } else {
            accentedForms.putIfAbsent(bare, () => <String>{}).add(lower);
          }
        }
      });

      final offenders = <String>[];
      bareUses.forEach((word, keys) {
        final accented = accentedForms[word];
        if (accented == null) return;
        final allowed = homographs[locale]![word];
        final unexplained = allowed == null
            ? keys
            : keys.where((key) => !allowed.allows(key)).toList();
        if (unexplained.isEmpty) return;
        offenders.add(
          '$word (${unexplained.length}x, e.g. ${unexplained.take(3).join(', ')}) '
          'is spelled ${accented.join(' / ')} elsewhere',
        );
      });

      expect(
        offenders,
        isEmpty,
        reason:
            '${offenders.length} word(s) in app_$locale.arb are written '
            'without their diacritics while the accented spelling is used '
            'elsewhere in the same file (issue #2235). Restore the accents, '
            'or, if both spellings are real words, add the word to the '
            'homographs map with the reason and, where the list is short, the '
            'keys the bare spelling belongs to.\n'
            '${offenders.join('\n')}',
      );
    });
  }

  test('app_pt.arb accents an infinitive that carries a clitic', () {
    final offenders = <String>[];
    readArb('pt').forEach((key, value) {
      for (final match in _clitic.allMatches(value)) {
        final verb = match.group(1)!;
        final last = withoutAccents(verb.toLowerCase()).split('').last;
        // "descartar" + "-las" is "descartá-las" and "ver" + "-la" is "vê-la";
        // an -ir verb keeps its bare vowel, as in "abri-lo".
        if (last == 'i' || verb != withoutAccents(verb)) continue;
        offenders.add('$key: ${match.group(0)}');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'A Portuguese -ar or -er infinitive takes an accent when a clitic '
          'follows it: "descartá-las", not "descarta-las" (issue #2235).\n'
          '${offenders.join('\n')}',
    );
  });

  test('app_es.arb accents its third-person preterites', () {
    // Regular preterites carry the accent; the strong ones never do.
    const strong = {
      'pudo',
      'puso',
      'hizo',
      'dijo',
      'trajo',
      'quiso',
      'supo',
      'tuvo',
      'estuvo',
      'anduvo',
      'produjo',
      'detuvo',
      'mantuvo',
      'obtuvo',
      'redujo',
      'condujo',
      'vino',
      'fue',
      'dio',
    };
    final reflexive = RegExp(
      r'(?<![A-Za-zÀ-ÿ])[Ss]e ([a-zà-ÿ]+o)(?![A-Za-zÀ-ÿ])',
    );
    // "fallo" is the noun in "Fallo del interruptor" and the verb everywhere
    // else: "La descarga falló".
    final failed = RegExp(
      r'(?<![A-Za-zÀ-ÿ])[Ff]allo(?![A-Za-zÀ-ÿ])(?! de| del)',
    );

    final offenders = <String>[];
    readArb('es').forEach((key, value) {
      for (final match in reflexive.allMatches(value)) {
        if (strong.contains(match.group(1))) continue;
        offenders.add('$key: "${match.group(0)}" needs the preterite accent');
      }
      if (failed.hasMatch(value)) {
        offenders.add('$key: "fallo" is the verb here, so it is "falló"');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'A Spanish third-person preterite is accented: "Se cambió a {name}", '
          '"La descarga falló" (issue #2235).\n${offenders.join('\n')}',
    );
  });
}

/// A word whose bare and accented spellings are both real words.
class _Homograph {
  const _Homograph(this.reason, {this.keys});

  final String reason;

  /// The keys the bare spelling may appear in, or null when the word is too
  /// common for a key list to be worth keeping current.
  final Set<String>? keys;

  bool allows(String key) => keys == null || keys!.contains(key);
}

/// A verb with a clitic pronoun attached, as in `descartá-las` or `abri-lo`.
final _clitic = RegExp(
  r'(?<![A-Za-zÀ-ÿ])([A-Za-zÀ-ÿ]+)-(?:la|lo|las|los)(?![A-Za-zÀ-ÿ])',
);

final _word = RegExp(r'[A-Za-zÀ-ÿ]+');

/// The words of an ARB value, skipping ICU argument names and selectors.
///
/// Brace depth alternates between message text and argument syntax:
/// `{count, plural, other{{count} inmersiones}}` contributes only
/// "inmersiones", never "count", "plural" or "other".
Iterable<String> messageWords(String value) sync* {
  var depth = 0;
  final segment = StringBuffer();
  for (final unit in value.split('')) {
    if (unit == '{' || unit == '}') {
      if (depth.isEven) {
        for (final match in _word.allMatches(segment.toString())) {
          yield match.group(0)!;
        }
      }
      segment.clear();
      depth += unit == '{' ? 1 : -1;
      continue;
    }
    segment.write(unit);
  }
  if (depth.isEven) {
    for (final match in _word.allMatches(segment.toString())) {
      yield match.group(0)!;
    }
  }
}

const _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// The Spanish and Portuguese letters, without their diacritics.
String withoutAccents(String word) {
  final buffer = StringBuffer();
  for (final unit in word.split('')) {
    buffer.write(_accents[unit] ?? unit);
  }
  return buffer.toString();
}
