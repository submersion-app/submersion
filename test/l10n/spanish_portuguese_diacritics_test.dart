import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Spanish and Portuguese ARBs against losing their diacritics
/// again, as issue #2235 found: `Pais` for `País`, `Configuracoes` for
/// `Configurações`, `Descompresion` for `Descompresión`.
///
/// The check needs no word list. A file that spells the same word both ways
/// contradicts itself, so any word written without its accents while the
/// accented spelling appears elsewhere in that same file is reported. That is
/// how the breakage looked: `Configuración` sat two lines from `Descompresion`.
///
/// Its blind spot is a word whose accented spelling appears nowhere in the file
/// at all, which no self-contained check can see. [homographs] lists the pairs
/// where both spellings are real words of the language and both belong here.
void main() {
  /// Words that legitimately appear with and without their accents, because
  /// the two spellings are different words.
  const homographs = <String, Map<String, String>>{
    'es': {
      'el': 'the article el, and the pronoun él',
      'que': 'the relative que, and the interrogative qué',
      'una': 'the article una, and uña, a claw',
      'este': 'the demonstrative este, and the subjunctive esté',
      'esta': 'the demonstrative esta, and the verb está',
      'estas': 'the demonstrative estas, and the verb estás',
      'como': 'como meaning as, and the interrogative cómo',
      'cuando': 'the relative cuando, and the interrogative cuándo',
      'donde': 'the relative donde, and the interrogative dónde',
      'si': 'the conditional si, and sí meaning yes',
      'min': 'min, the minutes unit, and mín. for mínimo',
      'max': 'Max in untranslated labels, and máx. for máximo',
      'master': 'Dive Master, a label kept in English, and máster',
      'registro': 'the noun registro, and the past tense registró',
      'cambio': 'the noun cambio, and the past tense cambió',
      'completo': 'the adjective completo, and the past tense completó',
      'fallo': 'the noun fallo, and the past tense falló',
      'paso': 'the noun paso, and the past tense pasó',
      'reemplazo': 'the noun reemplazo, and the past tense reemplazó',
      'continua': 'the adjective continua, and the verb continúa',
      'comenzara': 'the past subjunctive comenzara, and the future comenzará',
      'terminara': 'the past subjunctive terminara, and the future terminará',
      'cardiaca': 'the RAE accepts cardiaca beside cardíaca',
      'video': 'video in Latin America, vídeo in Spain; the file uses both',
      'videos': 'video in Latin America, vídeo in Spain; the file uses both',
    },
    'pt': {
      'a': 'the article a, and the contraction à',
      'as': 'the article as, and the contraction às',
      'da': 'the contraction da, and the verb dá',
      'de': 'the preposition de, and the imperative dê',
      'e': 'the conjunction e, and the verb é',
      'esta': 'the demonstrative esta, and the verb está',
      'la': 'the pronoun suffix -la, and lá meaning there',
      'le': 'Bluetooth LE, and the verb lê',
      'so': 'so in an untranslated sentence, and só meaning only',
      'tem': 'the singular tem, and the plural têm',
      'vem': 'the singular vem, and the plural vêm',
      'pode': 'the present pode, and the past pôde',
      'min': 'min, the minutes unit, and mín. for mínimo',
      'max': 'Max in untranslated labels, and máx. for máximo',
      'faca': 'faca, a knife, and faça, the subjunctive of fazer',
      'mares': 'mares, seas, and marés, tides',
      'media': 'media, the library, and média, an average',
      'analise': 'the imperative analise, and the noun análise',
      'continua': 'the verb continua, and the adjective contínua',
      'habitat': 'habitat and hábitat are both current in Portuguese',
      'oxigenio': 'oxigénio and oxigênio both appear; see issue #2235',
      'nitrogenio': 'nitrogénio and nitrogênio both appear; see issue #2235',
      // Verbs whose infinitive takes an accent only before a pronoun:
      // "remove" against "removê-la".
      'remove': 'remove, and removê- before a pronoun',
      'exclui': 'exclui, and excluí- before a pronoun',
      'descarta': 'descarta, and descartá- before a pronoun',
      'adota': 'adota, and adotá- before a pronoun',
      'trata': 'trata, and tratá- before a pronoun',
      'recupera': 'recupera, and recuperá- before a pronoun',
      'baixa': 'baixa, and baixá- before a pronoun',
      'usa': 'usa, and usá- before a pronoun',
      'marca': 'marca, and marcá- before a pronoun',
      'passa': 'passa, and passá- before a pronoun',
      'mostra': 'mostra, and mostrá- before a pronoun',
      'limpa': 'limpa, and limpá- before a pronoun',
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

  for (final locale in homographs.keys) {
    test(
      'app_$locale.arb spells no word both with and without its accents',
      () {
        final arb =
            jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;

        final accentedForms = <String, Set<String>>{};
        final bareUses = <String, List<String>>{};
        arb.forEach((key, value) {
          if (key.startsWith('@') ||
              value is! String ||
              untranslated[locale]!.contains(key)) {
            return;
          }
          for (final token in messageWords(value)) {
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
          if (accented == null || homographs[locale]!.containsKey(word)) return;
          offenders.add(
            '$word (${keys.length}x, e.g. ${keys.take(3).join(', ')}) '
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
              'homographs map in this test with the reason.\n'
              '${offenders.join('\n')}',
        );
      },
    );
  }
}

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
