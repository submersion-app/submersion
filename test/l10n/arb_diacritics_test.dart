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
/// #2283 added what the follow-up sweep found, including words garbled beyond
/// the accent (`Onodo` for `Ónos`, `Mindrestreserve` for `Mindestreserve`).
/// The same rule held: the French participles it restored (`ajouté`,
/// `visités`, `fermé`) and the `a`/`à`, `ou`/`où` and Dutch `een`/`één` fixes
/// are real words when unaccented, so only review can catch them regressing.
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
    'Banniere': 'Bannière',
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
    'controlent': 'contrôlent',
    'copiees': 'copiées',
    'Cout': 'Coût',
    'creation': 'création',
    'cumulees': 'cumulées',
    'Debit': 'Débit',
    'decision': 'décision',
    'Deconnecte': 'Déconnecté',
    'deconnectera': 'déconnectera',
    'decouvertes': 'découvertes',
    'Decouvrir': 'Découvrir',
    'Decroissant': 'Décroissant',
    'defiler': 'défiler',
    'Definissez': 'Définissez',
    'degage': 'dégagé',
    'delivrance': 'délivrance',
    'DELIVRE': 'DÉLIVRÉ',
    'DELIVREE': 'DÉLIVRÉE',
    'Delivree': 'Délivrée',
    'deplacee': 'déplacée',
    'deplacees': 'déplacées',
    'Derivante': 'Dérivante',
    'desaturent': 'désaturent',
    'deselectionnes': 'désélectionnés',
    'Desepingler': 'Désépingler',
    'Detail': 'Détail',
    'Detaille': 'Détaillé',
    'detectes': 'détectés',
    'determine': 'détermine',
    'Devidoir': 'Dévidoir',
    'Ecarts': 'Écarts',
    'Echelle': 'Échelle',
    'echouees': 'échouées',
    'Ecraser': 'Écraser',
    'Ecrire': 'Écrire',
    'ecrire': 'écrire',
    'ecrites': 'écrites',
    'ecriture': 'écriture',
    'Egypte': 'Égypte',
    'Entrainements': 'Entraînements',
    'epinglage': 'épinglage',
    'equilibree': 'équilibrée',
    'etablissement': 'établissement',
    'etoiles': 'étoiles',
    'exploree': 'explorée',
    'explorees': 'explorées',
    'extreme': 'extrême',
    'frequents': 'fréquents',
    'fusionne': 'fusionné',
    'fusionnes': 'fusionnés',
    'Geographie': 'Géographie',
    'grele': 'grêle',
    'icone': 'icône',
    'ideale': 'idéale',
    'illimitee': 'illimitée',
    'Imperial': 'Impérial',
    'Indonesie': 'Indonésie',
    'integrale': 'intégrale',
    'integrees': 'intégrées',
    'Invertebre': 'Invertébré',
    'journaliere': 'journalière',
    'leger': 'léger',
    'legere': 'légère',
    'liberera': 'libérera',
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
    'Penicilline': 'Pénicilline',
    'periodiquement': 'périodiquement',
    'Personnalise': 'Personnalisé',
    'personnalisees': 'personnalisées',
    'Photheque': 'Photothèque',
    'piece': 'pièce',
    'Possede': 'Possède',
    'Preferences': 'Préférences',
    'presume': 'présumé',
    'Pret': 'Prêt',
    'prevoir': 'prévoir',
    'prevue': 'prévue',
    'programmees': 'programmées',
    'rafraichissent': 'rafraîchissent',
    'reactive': 'réactivé',
    'recommande': 'recommandé',
    'Reduire': 'Réduire',
    'Regler': 'Régler',
    'reinitialisation': 'réinitialisation',
    'Reinitialisation': 'Réinitialisation',
    'reinitialise': 'réinitialisé',
    'renumerotees': 'renumérotées',
    'Renumeroter': 'Renuméroter',
    'reordonner': 'réordonner',
    'Repartition': 'Répartition',
    'resolu': 'résolu',
    'resolus': 'résolus',
    'resolution': 'résolution',
    'resoudre': 'résoudre',
    'Resoudre': 'Résoudre',
    'resultante': 'résultante',
    'retiree': 'retirée',
    'retirees': 'retirées',
    'retélechargeront': 'retéléchargeront',
    'revise': 'révisé',
    'saisonnieres': 'saisonnières',
    'scannees': 'scannées',
    'Selecteur': 'Sélecteur',
    'selecteur': 'sélecteur',
    'sequentiellement': 'séquentiellement',
    'sequentiels': 'séquentiels',
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
    'variete': 'variété',
    'verglacante': 'verglaçante',
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
    'Deiningsahoogte': 'Deiningshoogte',
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
    'instaptmethode': 'instapmethode',
    'Sidderemeerval': 'Siddermeerval',
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
    'Boja': 'Bója',
    'Buvarkoezpontok': 'Búvárközpontok',
    'búvárképesíte': 'búvárképesítési',
    'Cipok': 'Cipők',
    'Csempek': 'Csempék',
    'csempéjéet': 'csempéjét',
    'csoportositasa': 'csoportosítása',
    'Delnyugat': 'Délnyugat',
    'Derult': 'Derült',
    'derult': 'derült',
    'edzéseek': 'edzések',
    'Egyedulli': 'Egyedüli',
    'Egyedülli': 'Egyedüli',
    'Egyesíetés': 'Egyesítés',
    'Eldobas': 'Eldobás',
    'ellatas': 'ellátás',
    'Elokeszites': 'Előkészítés',
    'Elolap': 'Előlap',
    'eloszoba': 'előszoba',
    'elozmeny': 'előzmény',
    'előrehalads': 'előrehaladás',
    'Emlékeztetsek': 'Emlékeztetők',
    'emlékeztetsek': 'emlékeztetők',
    'Emlékeztetss': 'Emlékeztess',
    'ertekelesve': 'értékelve',
    'ertekelt': 'értékelt',
    'esedék': 'esedékes',
    'Eszakkelet': 'Északkelet',
    'Eszaknyugat': 'Északnyugat',
    'Eszrevetel': 'Észrevétel',
    'exportalasrol': 'exportálásról',
    'Faktorokrol': 'Faktorokról',
    'felhajtóerőe': 'felhajtóerő',
    'Felsos': 'Félsós',
    'Felszallas': 'Felszállás',
    'Felszerelesszettek': 'Felszerelésszettek',
    'Fooldal': 'Főoldal',
    'Gazcsereles': 'Gázcserélés',
    'Gazcserelesek': 'Gázcserélések',
    'Gazelemzes': 'Gázelemzés',
    'Gazok': 'Gázok',
    'görgetjen': 'görgessen',
    'Hajoszallasok': 'Hajószállások',
    'Hasznalas': 'Használás',
    'Hasznája': 'Használja',
    'Hatlap': 'Hátlap',
    'Hatragurulas': 'Hátragurulás',
    'Hattergaz': 'Háttérgáz',
    'hayl': 'havi',
    'Hazastars': 'Házastárs',
    'helymeghatározoási': 'helymeghatározási',
    'Helyszineim': 'Helyszíneim',
    'Higigaz': 'Hígítógáz',
    'higigaz': 'hígítógáz',
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
    'kabel': 'kábel',
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
    'Köblab': 'Köbláb',
    'kötelezetség': 'kötelezettség',
    'Lampa': 'Lámpa',
    'Latasvisszonyok': 'Látásviszonyok',
    'legséklyebb': 'legsekélyebb',
    'Legutobbl': 'Legutóbbi',
    'Legutóbbl': 'Legutóbbi',
    'lejaarat': 'lejárat',
    'lejaart': 'lejárt',
    'LEJAROBAN': 'LEJÁRÓBAN',
    'lejártt': 'lejárt',
    'Letra': 'Létra',
    'Maj.': 'Máj.',
    'Maldiv': 'Maldív',
    'Mar.': 'Márc.',
    'Maradas': 'Maradás',
    'Media': 'Média',
    'Megerosites': 'Megerősítés',
    'Megtekindés': 'Megtekintés',
    'megtekintobezerarasa': 'bezárása',
    'megállóket': 'megállókat',
    'megállóást': 'megállást',
    'melymerules': 'mélymerülés',
    'Menu': 'Menü',
    'Merfoldk9vek': 'Mérföldkövek',
    'Merulesido': 'Merülésidő',
    'Merulestervezo,': 'Merüléstervező,',
    'Merulocentrumok': 'Merülőcentrumok',
    'Merulotarssal': 'Merülőtárssal',
    'merülseket': 'merüléseket',
    'merülőszámítógéből': 'merülőszámítógépből',
    'Mesteroktato': 'Mesteroktató',
    'Monokrom': 'Monokróm',
    'Nehezsseg': 'Nehézség',
    'Nehezssgi': 'Nehézségi',
    'Oldalmerret': 'Oldalméret',
    'Onodo': 'Ónos',
    'Opciok': 'Opciók',
    'osszecsuklasa': 'összecsukása',
    'Osztaly': 'Osztály',
    'osztaly': 'osztály',
    'Palackkonfiguracio': 'Palackkonfiguráció',
    'Rategek': 'Rétegek',
    'Rekreaccios': 'Rekreációs',
    'rekreacciós': 'rekreációs',
    'Rolunk': 'Rólunk',
    'sebessg': 'sebesség',
    'Sebessg': 'Sebesség',
    'Segitseg': 'Segítség',
    'Sosviz': 'Sósvíz',
    'specifikaciok': 'specifikációk',
    'stilusu': 'stílusú',
    'Sugo': 'Súgó',
    'Suly': 'Súly',
    'sulya': 'súlya',
    'Sulyoev': 'Súlyöv',
    'Sulyszamitas': 'Súlyszámítás',
    'Sulyszamologep': 'Súlyszámológép',
    'Szabadmerules': 'Szabadmerülés',
    'szabalyozott': 'szabályozott',
    'Szam.': 'Szám.',
    'szamologepek': 'számológépek',
    'szelcsend': 'szélcsend',
    'Szenalas': 'Szénszálas',
    'szervizeltkéntt': 'szervizeltként',
    'Szinatlenet': 'Színátmenet',
    'Szorokeszulek': 'Szűrőkészülék',
    'Szovettelitodes': 'Szövettelítődés',
    'Szovetterheltseg': 'Szövetterheltség',
    'Szülo': 'Szülő',
    'sértetetlenek': 'sértetlenek',
    'Tanfolyamigazgato': 'Tanfolyamigazgató',
    'tartományoként': 'tartományonként',
    'Teknosbeka': 'Teknősbéka',
    'tevékenyse': 'tevékenység',
    'tevékenységeadatai': 'tevékenységadatai',
    'Tulnyomoan': 'Túlnyomóan',
    'térképrégiit': 'térképrégiót',
    'Ujraaktivalas': 'Újraaktiválás',
    'Ujraproba': 'Újrapróba',
    'Ujraszamozas': 'Újraszámozás',
    'Utifotok': 'Útifotók',
    'valtozas': 'változás',
    'Veszélyzeti': 'Vészhelyzeti',
    'Zaporeso': 'Záporeső',
    'Üresbben': 'Üresen',
    'ütemezerésre': 'ütemezésre',
    // Not a misspelling: `deko` is everyday Hungarian for a decagram.
    // In this app it always means decompression, and #2283 settled on
    // `Dekó` so the file stops spelling it both ways.
    'DEKO': 'DEKÓ',
    'Deko': 'Dekó',
    'deko': 'dekó',
  },
  // German
  'de': <String, String>{
    'aendern': 'ändern',
    'ausser': 'außer',
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
    'Mindrestreserve': 'Mindestreserve',
    'mitgefuhrt': 'mitgeführt',
    'Nachstes': 'Nächstes',
    'Piracurù': 'Pirarucu',
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
