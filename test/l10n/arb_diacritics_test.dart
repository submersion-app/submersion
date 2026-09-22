import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the four locales swept in #2245 against losing their diacritics
/// again.
///
/// French (#1608), German (#262) and Hungarian (#2047) were each swept once
/// before, and every string listed here was written *after* that sweep landed.
/// The files disagreed with themselves as a result: `app_de.arb` spelled `für`
/// 205 times and `fur` four, `app_nl.arb` spelled `geïmporteerd` 41 times and
/// `geimporteerd` 14. That is a regression, not unfinished translation, so it
/// needs a guard rather than another sweep.
///
/// Each entry is a form that is **not a word** in its language, paired with the
/// spelling that was meant. Near-identical real words are deliberately absent:
/// German `lange`, `plane`, `trage` and `Rohre` are correct and have umlauted
/// look-alikes (`Länge`, `Pläne`, `träge`, `Röhre`); Dutch `gedetecteerd` and
/// `geanalyseerd` take no trema; Hungarian `akar`, `keres`, `szeretne` and
/// `szoros` are correct beside `akár`, `kérés`, `szeretné` and `szőrös`. A
/// pattern-based rule would corrupt all of those, which is why this list is
/// enumerated rather than derived.
///
/// Arabic, Hebrew and Chinese are not listed: modern Arabic and Hebrew
/// normally omit their diacritics, and that is correct.
const _forbiddenSpellings = <String, Map<String, String>>{
  // French
  'fr': <String, String>{
    'acceder': 'accéder',
    'ajoutee': 'ajoutée',
    'Arreter': 'Arrêter',
    'assignees': 'assignées',
    'BIENTOT': 'BIENTÔT',
    'bientot': 'bientôt',
    'binome': 'binôme',
    'binomes': 'binômes',
    'boite': 'boîte',
    'Bouee': 'Bouée',
    'Cable': 'Câble',
    'calculee': 'calculée',
    'Camera': 'Caméra',
    'capturee': 'capturée',
    'colorees': 'colorées',
    'colores': 'colorés',
    'completes': 'complètes',
    'copiees': 'copiées',
    'creation': 'création',
    'cumulees': 'cumulées',
    'Debit': 'Débit',
    'Definissez': 'Définissez',
    'degage': 'dégagé',
    'delivrance': 'délivrance',
    'DELIVREE': 'DÉLIVRÉE',
    'Delivree': 'Délivrée',
    'deplacee': 'déplacée',
    'deplacees': 'déplacées',
    'desaturent': 'désaturent',
    'deselectionnes': 'désélectionnés',
    'Desepingler': 'Désépingler',
    'Detail': 'Détail',
    'Detaille': 'Détaillé',
    'Echelle': 'Échelle',
    'echouees': 'échouées',
    'Ecraser': 'Écraser',
    'Ecrire': 'Écrire',
    'ecrire': 'écrire',
    'ecrites': 'écrites',
    'ecriture': 'écriture',
    'Egypte': 'Égypte',
    'Entrainements': 'Entraînements',
    'equilibree': 'équilibrée',
    'etablissement': 'établissement',
    'etoiles': 'étoiles',
    'exploree': 'explorée',
    'explorees': 'explorées',
    'extreme': 'extrême',
    'fusionne': 'fusionné',
    'fusionnes': 'fusionnés',
    'grele': 'grêle',
    'icone': 'icône',
    'illimitee': 'illimitée',
    'Imperial': 'Impérial',
    'Indonesie': 'Indonésie',
    'integrale': 'intégrale',
    'integrees': 'intégrées',
    'Invertebre': 'Invertébré',
    'leger': 'léger',
    'legere': 'légère',
    'Mammifere': 'Mammifère',
    'matiere': 'matière',
    'medical': 'médical',
    'medicales': 'médicales',
    'Medicaments': 'Médicaments',
    'meduses': 'méduses',
    'melanges': 'mélanges',
    'Modere': 'Modéré',
    'moderee': 'modérée',
    'negative': 'négative',
    'Operateurs': 'Opérateurs',
    'partagees': 'partagées',
    'periodiquement': 'périodiquement',
    'Personnalise': 'Personnalisé',
    'personnalisees': 'personnalisées',
    'piece': 'pièce',
    'Possede': 'Possède',
    'Preferences': 'Préférences',
    'prevoir': 'prévoir',
    'prevue': 'prévue',
    'programmees': 'programmées',
    'rafraichissent': 'rafraîchissent',
    'recommande': 'recommandé',
    'Reduire': 'Réduire',
    'reinitialisation': 'réinitialisation',
    'Reinitialisation': 'Réinitialisation',
    'reinitialise': 'réinitialisé',
    'renumerotees': 'renumérotées',
    'Renumeroter': 'Renuméroter',
    'reordonner': 'réordonner',
    'Repartition': 'Répartition',
    'resolution': 'résolution',
    'resoudre': 'résoudre',
    'Resoudre': 'Résoudre',
    'retiree': 'retirée',
    'retirees': 'retirées',
    'revise': 'révisé',
    'saisonnieres': 'saisonnières',
    'scannees': 'scannées',
    'Selecteur': 'Sélecteur',
    'selecteur': 'sélecteur',
    'sequentiellement': 'séquentiellement',
    'Specifications': 'Spécifications',
    'specifie': 'spécifié',
    'stockees': 'stockées',
    'supplementaire': 'supplémentaire',
    'supplementaires': 'supplémentaires',
    'Thailande': 'Thaïlande',
    'tolerance': 'tolérance',
    'Toxicite': 'Toxicité',
    'toxicite': 'toxicité',
    'trouves': 'trouvés',
  },
  // Dutch
  'nl': <String, String>{
    'Allergieen': 'Allergieën',
    'beinvloed': 'beïnvloed',
    'beinvloeden': 'beïnvloeden',
    'beinvloedt': 'beïnvloedt',
    'categorieen': 'categorieën',
    'cloudkopieen': 'cloudkopieën',
    'Coordinaten': 'Coördinaten',
    'coordinaten': 'coördinaten',
    'geexporteerd': 'geëxporteerd',
    'Geimporteerd': 'Geïmporteerd',
    'geimporteerd': 'geïmporteerd',
    'Geimporteerde': 'Geïmporteerde',
    'geimporteerde': 'geïmporteerde',
    'Geupload': 'Geüpload',
    'geupload': 'geüpload',
    'Gradientfactoren': 'Gradiëntfactoren',
    'gradientfactoren': 'gradiëntfactoren',
    'Gradientfactormetrieken': 'Gradiëntfactormetrieken',
    'Indonesie': 'Indonesië',
  },
  // Hungarian
  'hu': <String, String>{
    'aktiv': 'aktív',
    'Apr.': 'Ápr.',
    'bejelentese': 'bejelentése',
    'bevetel': 'bevitel',
    'Billentyuparancsok': 'Billentyűparancsok',
    'Buvarkoezpontok': 'Búvárközpontok',
    'csoportositasa': 'csoportosítása',
    'Egyedulli': 'Egyedüli',
    'Elokeszites': 'Előkészítés',
    'ertekelesve': 'értékelve',
    'ertekelt': 'értékelt',
    'Felszallas': 'Felszállás',
    'Felszerelesszettek': 'Felszerelésszettek',
    'Hatlap': 'Hátlap',
    'Hatragurulas': 'Hátragurulás',
    'hozzaadasa': 'hozzáadása',
    'idoezitese': 'időzítése',
    'Idomintak': 'Időminták',
    'Jul.': 'Júl.',
    'Jun.': 'Jún.',
    'Kesztyuk': 'Kesztyűk',
    'kinyitasa': 'kinyitása',
    'Legutobbl': 'Legutóbbi',
    'lejaarat': 'lejárat',
    'Maj.': 'Máj.',
    'Mar.': 'Márc.',
    'Media': 'Média',
    'Megerosites': 'Megerősítés',
    'megtekintobezerarasa': 'bezárása',
    'melymerules': 'mélymerülés',
    'Menu': 'Menü',
    'Merulesido': 'Merülésidő',
    'Merulestervezo,': 'Merüléstervező,',
    'Merulocentrumok': 'Merülőcentrumok',
    'Merulotarssal': 'Merülőtárssal',
    'Monokrom': 'Monokróm',
    'Nehezsseg': 'Nehézség',
    'Nehezssgi': 'Nehézségi',
    'osszecsuklasa': 'összecsukása',
    'Rekreaccios': 'Rekreációs',
    'sebessg': 'sebesség',
    'Sebessg': 'Sebesség',
    'Segitseg': 'Segítség',
    'Suly': 'Súly',
    'Sulyoev': 'Súlyöv',
    'Sulyszamitas': 'Súlyszámítás',
    'Sulyszamologep': 'Súlyszámológép',
    'Szabadmerules': 'Szabadmerülés',
    'Szam.': 'Szám.',
    'szamologepek': 'számológépek',
    'Szinatlenet': 'Színátmenet',
    'Szovetterheltseg': 'Szövetterheltség',
    'Ujraaktivalas': 'Újraaktiválás',
    'Ujraproba': 'Újrapróba',
    'Ujraszamozas': 'Újraszámozás',
  },
  // German
  'de': <String, String>{
    'aendern': 'ändern',
    'benotigen': 'benötigen',
    'Bestaetigungsfelder': 'Bestätigungsfelder',
    'bewolkt': 'bewölkt',
    'einfuegen': 'einfügen',
    'Flaschendrucke': 'Flaschendrücke',
    'fuer': 'für',
    'fur': 'für',
    'Gegenstaende': 'Gegenstände',
    'Groesse': 'Größe',
    'hinzufugen': 'hinzufügen',
    'losen': 'lösen',
    'mitgefuhrt': 'mitgeführt',
    'Nachstes': 'Nächstes',
    'Prufe': 'Prüfe',
    'Schliesse': 'Schließe',
    'Taglich': 'Täglich',
    'Tauchgaenge': 'Tauchgänge',
    'Tauchgaengen': 'Tauchgängen',
    'Tauchplaetze': 'Tauchplätze',
    'Uber': 'Über',
    'uberschreitet': 'überschreitet',
    'Uberwiegend': 'Überwiegend',
    'Verbandspruefung': 'Verbandsprüfung',
    'Verknuepfen': 'Verknüpfen',
    'Wochentlich': 'Wöchentlich',
  },
};

/// Keeps an ICU message's prose and drops its syntax, with a balanced walk.
///
/// Regex stripping cannot do this, and failed twice while this sweep was
/// written. A flat `\{[^{}]*\}` matches the *innermost* braces, so on
/// `{count, plural, =1{plongée deplacee} other{...}}` it deletes the branch
/// text rather than the argument name; that is how `deplacee` and `retiree`
/// first survived. Stripping `{name}` placeholders before the complex-argument
/// header has the same effect on a one-word branch - `=1{fur}` looks exactly
/// like a placeholder - and on every branch of a `select` whose keys are not
/// plural categories, such as `{type, select, ccr{CCR} other{OC}}`. That
/// second gap hid five German transliterations (`Tauchgaenge`, `Tauchplaetze`,
/// `Gegenstaende`, `Tauchgaengen`, `Verknuepfen`) and French `binome`.
///
/// Argument *names* are still dropped, because they are identifiers rather
/// than prose: `{resolution}` must not read as a misspelling of `résolution`.
String arbProse(String value) {
  final out = StringBuffer();
  // Which brace each open `{` belongs to: a plural/select argument, or one of
  // its branch bodies. Only inside the former does a `{` open a branch.
  final stack = <_Brace>[];
  var text = '';

  void flush() {
    if (text.isNotEmpty) {
      out.write(text);
      text = '';
    }
  }

  var i = 0;
  while (i < value.length) {
    final ch = value[i];
    if (ch == '}') {
      if (stack.isNotEmpty) stack.removeLast();
      flush();
      out.write(' ');
      i++;
      continue;
    }
    if (ch != '{') {
      text += ch;
      i++;
      continue;
    }
    if (stack.isNotEmpty &&
        stack.last == _Brace.argument &&
        _selectorTail.hasMatch(text)) {
      text = text.replaceFirst(_selectorTail, '');
      flush();
      out.write(' ');
      stack.add(_Brace.branch);
      i++;
      continue;
    }
    final header = _complexHeader.matchAsPrefix(value, i);
    if (header != null) {
      flush();
      out.write(' ');
      stack.add(_Brace.argument);
      i = header.end;
      continue;
    }
    final simple = _simpleArgument.matchAsPrefix(value, i);
    if (simple != null) {
      flush();
      out.write(' ');
      i = simple.end;
      continue;
    }
    flush();
    out.write(' ');
    stack.add(_Brace.branch);
    i++;
  }
  flush();
  return out.toString();
}

enum _Brace { argument, branch }

final _simpleArgument = RegExp(r'\{\s*\w+\s*\}');
final _complexHeader = RegExp(r'\{\s*\w+\s*,\s*\w+\s*,');
final _selectorTail = RegExp(r'(?:=\d+|\w+)\s*$');

void main() {
  group('ARB values keep their diacritics', () {
    _forbiddenSpellings.forEach((locale, spellings) {
      test('app_$locale.arb spells no word without its diacritics', () {
        final arb =
            jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;

        final offenders = <String>[];
        arb.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          final prose = arbProse(value);
          spellings.forEach((bare, correct) {
            final pattern = RegExp(
              '(?<!\\p{L})${RegExp.escape(bare)}(?!\\p{L})',
              unicode: true,
            );
            if (pattern.hasMatch(prose)) {
              offenders.add('$key: "$bare" should be "$correct"');
            }
          });
        });

        expect(
          offenders,
          isEmpty,
          reason:
              '${offenders.length} value(s) in app_$locale.arb dropped a '
              'diacritic. Restore the accented spelling and re-run '
              '`flutter gen-l10n`:\n${offenders.join('\n')}',
        );
      });
    });
  });
}
