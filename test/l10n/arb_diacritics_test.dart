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
    'attribues': 'attribués',
    'BIENTOT': 'BIENTÔT',
    'bientot': 'bientôt',
    'binome': 'binôme',
    'binomes': 'binômes',
    'boite': 'boîte',
    'Bouee': 'Bouée',
    'ca': 'ça',
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
    'decision': 'décision',
    'Deconnecte': 'Déconnecté',
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
    'determine': 'détermine',
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
    'Numeroter': 'Numéroter',
    'Operateurs': 'Opérateurs',
    'partagees': 'partagées',
    'periodiquement': 'périodiquement',
    'Personnalise': 'Personnalisé',
    'personnalisees': 'personnalisées',
    'piece': 'pièce',
    'Possede': 'Possède',
    'Preferences': 'Préférences',
    'presume': 'présumé',
    'prevoir': 'prévoir',
    'prevue': 'prévue',
    'programmees': 'programmées',
    'rafraichissent': 'rafraîchissent',
    'reactive': 'réactivé',
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
    'Adattipus': 'Adattípus',
    'aktiv': 'aktív',
    'Alairta': 'Aláírta',
    'Apr.': 'Ápr.',
    'bejelentese': 'bejelentése',
    'bevetel': 'bevitel',
    'Billentyuparancsok': 'Billentyűparancsok',
    'Buvarkoezpontok': 'Búvárközpontok',
    'Cipok': 'Cipők',
    'Csempek': 'Csempék',
    'csoportositasa': 'csoportosítása',
    'Delnyugat': 'Délnyugat',
    'Derult': 'Derült',
    'derult': 'derült',
    'Egyedulli': 'Egyedüli',
    'Egyedülli': 'Egyedüli',
    'Eldobas': 'Eldobás',
    'ellatas': 'ellátás',
    'Elokeszites': 'Előkészítés',
    'Elolap': 'Előlap',
    'eloszoba': 'előszoba',
    'elozmeny': 'előzmény',
    'ertekelesve': 'értékelve',
    'ertekelt': 'értékelt',
    'Eszakkelet': 'Északkelet',
    'Eszaknyugat': 'Északnyugat',
    'Eszrevetel': 'Észrevétel',
    'exportalasrol': 'exportálásról',
    'Faktorokrol': 'Faktorokról',
    'Felsos': 'Félsós',
    'Felszallas': 'Felszállás',
    'Felszerelesszettek': 'Felszerelésszettek',
    'Fooldal': 'Főoldal',
    'Gazcsereles': 'Gázcserélés',
    'Gazcserelesek': 'Gázcserélések',
    'Gazelemzes': 'Gázelemzés',
    'Gazok': 'Gázok',
    'Hajoszallasok': 'Hajószállások',
    'Hasznalas': 'Használás',
    'Hatlap': 'Hátlap',
    'Hatragurulas': 'Hátragurulás',
    'Hattergaz': 'Háttérgáz',
    'Helyszineim': 'Helyszíneim',
    'Higigaz': 'Hígítógáz',
    'Higito': 'Hígító',
    'Hodara': 'Hódara',
    'Hozapor': 'Hózápor',
    'hozzaadasa': 'hozzáadása',
    'idoezitese': 'időzítése',
    'Idomintak': 'Időminták',
    'importalasrol': 'importálásról',
    'Indonezia': 'Indonézia',
    'jegesovel': 'jégesővel',
    'Jul.': 'Júl.',
    'Jun.': 'Jún.',
    'Kepesitette': 'Képesítette',
    'kepzest': 'képzést',
    'Kesztyuk': 'Kesztyűk',
    'KIALLITVA': 'KIÁLLÍTVA',
    'Kiallitva': 'Kiállítva',
    'Kikotos': 'Kikötős',
    'kinyitasa': 'kinyitása',
    'Kolcsonadva': 'Kölcsönadva',
    'konfiguracoo': 'konfiguráció',
    'Konyvjelzo': 'Könyvjelző',
    'Kozpontok': 'Központok',
    'Lampa': 'Lámpa',
    'Latasvisszonyok': 'Látásviszonyok',
    'Legutobbl': 'Legutóbbi',
    'lejaarat': 'lejárat',
    'lejaart': 'lejárt',
    'LEJAROBAN': 'LEJÁRÓBAN',
    'Letra': 'Létra',
    'Maj.': 'Máj.',
    'Maldiv': 'Maldív',
    'Mar.': 'Márc.',
    'Maradas': 'Maradás',
    'Media': 'Média',
    'Megerosites': 'Megerősítés',
    'megtekintobezerarasa': 'bezárása',
    'melymerules': 'mélymerülés',
    'Menu': 'Menü',
    'Merfoldk9vek': 'Mérföldkövek',
    'Merulesido': 'Merülésidő',
    'Merulestervezo,': 'Merüléstervező,',
    'Merulocentrumok': 'Merülőcentrumok',
    'Merulotarssal': 'Merülőtárssal',
    'Mesteroktato': 'Mesteroktató',
    'Monokrom': 'Monokróm',
    'Nehezsseg': 'Nehézség',
    'Nehezssgi': 'Nehézségi',
    'Oldalmerret': 'Oldalméret',
    'Opciok': 'Opciók',
    'osszecsuklasa': 'összecsukása',
    'Osztaly': 'Osztály',
    'Palackkonfiguracio': 'Palackkonfiguráció',
    'Rategek': 'Rétegek',
    'Rekreaccios': 'Rekreációs',
    'Rolunk': 'Rólunk',
    'sebessg': 'sebesség',
    'Sebessg': 'Sebesség',
    'Segitseg': 'Segítség',
    'Sosviz': 'Sósvíz',
    'specifikaciok': 'specifikációk',
    'stilusu': 'stílusú',
    'Sugo': 'Súgó',
    'Suly': 'Súly',
    'Sulyoev': 'Súlyöv',
    'Sulyszamitas': 'Súlyszámítás',
    'Sulyszamologep': 'Súlyszámológép',
    'Szabadmerules': 'Szabadmerülés',
    'szabalyozott': 'szabályozott',
    'Szam.': 'Szám.',
    'szamologepek': 'számológépek',
    'szelcsend': 'szélcsend',
    'Szenalas': 'Szénszálas',
    'Szinatlenet': 'Színátmenet',
    'Szorokeszulek': 'Szűrőkészülék',
    'Szovettelitodes': 'Szövettelítődés',
    'Szovetterheltseg': 'Szövetterheltség',
    'Tanfolyamigazgato': 'Tanfolyamigazgató',
    'Teknosbeka': 'Teknősbéka',
    'Tulnyomoan': 'Túlnyomóan',
    'Ujraaktivalas': 'Újraaktiválás',
    'Ujraproba': 'Újrapróba',
    'Ujraszamozas': 'Újraszámozás',
    'Utifotok': 'Útifotók',
    'valtozas': 'változás',
    'Zaporeso': 'Záporeső',
  },
  // German
  'de': <String, String>{
    'aendern': 'ändern',
    'benotigen': 'benötigen',
    'Bestaetigungsfelder': 'Bestätigungsfelder',
    'bewolkt': 'bewölkt',
    'Drucke': 'Drücke',
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
    'Problemlosung': 'Problemlösung',
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
    'zugefugt': 'zugefügt',
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
