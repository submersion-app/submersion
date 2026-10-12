import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3016: the Dive focus summary and coverage strings embedded their
/// counts without plural handling, so a one-dive population read "Only 1 dives
/// have this value".
///
/// Each case is (singular, plural) for every shipped locale.
typedef _Cases = Map<String, (String, String)>;

void main() {
  Future<AppLocalizations> load(String languageCode) =>
      AppLocalizations.delegate.load(Locale(languageCode));

  final codes = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();

  void check(
    String key,
    String Function(AppLocalizations l10n) singular,
    String Function(AppLocalizations l10n) plural,
    _Cases expected,
  ) {
    group(key, () {
      test('covers every shipped locale', () {
        expect(expected.keys.toSet(), codes);
      });
      for (final MapEntry(key: code, value: (one, many)) in expected.entries) {
        test('$code agrees with its own count', () async {
          final l10n = await load(code);

          expect(singular(l10n), one);
          expect(plural(l10n), many);
        });
      }
    });
  }

  check(
    'insights_focus_summary_allShown',
    (l) => l.insights_focus_summary_allShown(1),
    (l) => l.insights_focus_summary_allShown(3),
    {
      'en': (
        'Only 1 dive has this value, so it is shown',
        'Only 3 dives have this value, so all of them are shown',
      ),
      'ar': (
        'غطسة واحدة فقط لها هذه القيمة، لذا تُعرض',
        '3 غطسات فقط لها هذه القيمة، لذا تُعرض جميعها',
      ),
      'de': (
        'Nur 1 Tauchgang hat diesen Wert, daher wird er angezeigt',
        'Nur 3 Tauchgänge haben diesen Wert, daher werden alle angezeigt',
      ),
      'es': (
        'Solo 1 inmersión tiene este valor, así que se muestra',
        'Solo 3 inmersiones tienen este valor, así que se muestran todas',
      ),
      'fr': (
        'Seule 1 plongée a cette valeur, elle est donc affichée',
        'Seules 3 plongées ont cette valeur, elles sont donc toutes affichées',
      ),
      'he': (
        'רק לצלילה אחת יש ערך זה, ולכן היא מוצגת',
        'רק ל־3 צלילות יש ערך זה, ולכן כולן מוצגות',
      ),
      'hu': (
        'Csak 1 merülésnek van ilyen értéke, ezért az jelenik meg',
        'Csak 3 merülésnek van ilyen értéke, ezért mind megjelenik',
      ),
      'it': (
        'Solo 1 immersione ha questo valore, quindi viene mostrata',
        'Solo 3 immersioni hanno questo valore, quindi vengono mostrate tutte',
      ),
      'nl': (
        'Slechts 1 duik heeft deze waarde, dus die wordt getoond',
        'Slechts 3 duiken hebben deze waarde, dus ze worden allemaal getoond',
      ),
      'pt': (
        'Apenas 1 mergulho tem este valor, por isso é mostrado',
        'Apenas 3 mergulhos têm este valor, por isso são todos mostrados',
      ),
      'zh': ('只有 1 次潜水有此数值，因此显示这一次', '只有 3 次潜水有此数值，因此全部显示'),
    },
  );

  check(
    'insights_focus_factors_coverage',
    (l) => l.insights_focus_factors_coverage(1, 1),
    (l) => l.insights_focus_factors_coverage(2, 3),
    {
      'en': ('1 of 1 dive', '2 of 3 dives'),
      'ar': ('1 من غطسة واحدة', '2 من 3 غطسات'),
      'de': ('1 von 1 Tauchgang', '2 von 3 Tauchgängen'),
      'es': ('1 de 1 inmersión', '2 de 3 inmersiones'),
      'fr': ('1 plongée sur 1', '2 plongées sur 3'),
      'he': ('1 מתוך צלילה אחת', '2 מתוך 3 צלילות'),
      'hu': ('1 / 1 merülés', '2 / 3 merülés'),
      'it': ('1 immersione su 1', '2 immersioni su 3'),
      'nl': ('1 van 1 duik', '2 van 3 duiken'),
      'pt': ('1 de 1 mergulho', '2 de 3 mergulhos'),
      'zh': ('1 次中的 1 次', '3 次中的 2 次'),
    },
  );

  check(
    'insights_focus_summary',
    (l) => l.insights_focus_summary(1, 1, 'G', 'O'),
    (l) => l.insights_focus_summary(2, 3, 'G', 'O'),
    {
      'en': (
        '1 of 1 dive. Average G, against O across all your dives.',
        '2 of 3 dives. Average G, against O across all your dives.',
      ),
      'ar': (
        '1 من غطسة واحدة. المتوسط G، مقابل O عبر كل غطساتك.',
        '2 من 3 غطسات. المتوسط G، مقابل O عبر كل غطساتك.',
      ),
      'de': (
        '1 von 1 Tauchgang. Durchschnitt G, gegenüber O über alle deine '
            'Tauchgänge.',
        '2 von 3 Tauchgängen. Durchschnitt G, gegenüber O über alle deine '
            'Tauchgänge.',
      ),
      'es': (
        '1 de 1 inmersión. Media G, frente a O en todas tus inmersiones.',
        '2 de 3 inmersiones. Media G, frente a O en todas tus inmersiones.',
      ),
      'fr': (
        '1 plongée sur 1. Moyenne G, contre O sur toutes vos plongées.',
        '2 plongées sur 3. Moyenne G, contre O sur toutes vos plongées.',
      ),
      'he': (
        '1 מתוך צלילה אחת. ממוצע G, לעומת O בכל הצלילות שלך.',
        '2 מתוך 3 צלילות. ממוצע G, לעומת O בכל הצלילות שלך.',
      ),
      'hu': (
        '1 / 1 merülés. Átlag G, szemben az összes merülésed O értékével.',
        '2 / 3 merülés. Átlag G, szemben az összes merülésed O értékével.',
      ),
      'it': (
        '1 immersione su 1. Media G, contro O su tutte le tue immersioni.',
        '2 immersioni su 3. Media G, contro O su tutte le tue immersioni.',
      ),
      'nl': (
        '1 van 1 duik. Gemiddelde G, tegenover O over al je duiken.',
        '2 van 3 duiken. Gemiddelde G, tegenover O over al je duiken.',
      ),
      'pt': (
        '1 de 1 mergulho. Média G, contra O em todos os seus mergulhos.',
        '2 de 3 mergulhos. Média G, contra O em todos os seus mergulhos.',
      ),
      'zh': ('1 次潜水中的 1 次。平均 G，全部潜水为 O。', '3 次潜水中的 2 次。平均 G，全部潜水为 O。'),
    },
  );

  check(
    'insights_focus_list_showAll',
    (l) => l.insights_focus_list_showAll(1),
    (l) => l.insights_focus_list_showAll(6),
    {
      'en': ('Show the 1 dive', 'Show all 6 dives'),
      'ar': ('اعرض الغطسة', 'اعرض كل الغطسات الـ6'),
      'de': ('Den 1 Tauchgang zeigen', 'Alle 6 Tauchgänge zeigen'),
      'es': ('Mostrar la 1 inmersión', 'Mostrar las 6 inmersiones'),
      'fr': ('Afficher la plongée', 'Afficher les 6 plongées'),
      'he': ('הצג את הצלילה', 'הצג את כל 6 הצלילות'),
      'hu': ('Az 1 merülés mutatása', 'Mind a(z) 6 merülés mutatása'),
      'it': ("Mostra l'immersione", 'Mostra tutte le 6 immersioni'),
      'nl': ('Toon de 1 duik', 'Toon alle 6 duiken'),
      'pt': ('Mostrar o mergulho', 'Mostrar todos os 6 mergulhos'),
      'zh': ('显示这 1 次潜水', '显示全部 6 次潜水'),
    },
  );

  check(
    'insights_focus_standouts_more',
    (l) => l.insights_focus_standouts_more(1),
    (l) => l.insights_focus_standouts_more(3),
    {
      'en': (
        'and 1 more in the full comparison',
        'and 3 more in the full comparison',
      ),
      'ar': ('وواحدة أخرى في المقارنة الكاملة', 'و3 أخرى في المقارنة الكاملة'),
      'de': (
        'und 1 weiterer im vollständigen Vergleich',
        'und 3 weitere im vollständigen Vergleich',
      ),
      'es': (
        'y 1 más en la comparación completa',
        'y 3 más en la comparación completa',
      ),
      'fr': (
        'et 1 de plus dans la comparaison complète',
        'et 3 de plus dans la comparaison complète',
      ),
      'he': ('ועוד אחד בהשוואה המלאה', 'ועוד 3 בהשוואה המלאה'),
      'hu': (
        'és még 1 a teljes összehasonlításban',
        'és még 3 a teljes összehasonlításban',
      ),
      'it': (
        'e 1 altro nel confronto completo',
        'e altri 3 nel confronto completo',
      ),
      'nl': (
        'en 1 meer in de volledige vergelijking',
        'en 3 meer in de volledige vergelijking',
      ),
      'pt': (
        'e mais 1 na comparação completa',
        'e mais 3 na comparação completa',
      ),
      'zh': ('完整对比中还有 1 项', '完整对比中还有 3 项'),
    },
  );

  check(
    'insights_focus_comparison_showMore',
    (l) => l.insights_focus_comparison_showMore(1),
    (l) => l.insights_focus_comparison_showMore(4),
    {
      'en': ('Show 1 more factor', 'Show 4 more factors'),
      'ar': ('اعرض عاملاً آخر', 'اعرض 4 عوامل أخرى'),
      'de': ('1 weiteren Faktor zeigen', '4 weitere Faktoren zeigen'),
      'es': ('Mostrar 1 factor más', 'Mostrar 4 factores más'),
      'fr': ('Afficher 1 facteur de plus', 'Afficher 4 facteurs de plus'),
      'he': ('הצג גורם נוסף', 'הצג 4 גורמים נוספים'),
      'hu': ('Még 1 tényező mutatása', 'Még 4 tényező mutatása'),
      'it': ('Mostra 1 altro fattore', 'Mostra altri 4 fattori'),
      'nl': ('Toon 1 factor meer', 'Toon 4 factoren meer'),
      'pt': ('Mostrar mais 1 fator', 'Mostrar mais 4 fatores'),
      'zh': ('显示另外 1 项因素', '显示另外 4 项因素'),
    },
  );

  group('French and Italian agree with the counted part', () {
    test('a single covered dive out of several is singular', () async {
      final fr = await load('fr');
      final it = await load('it');

      expect(fr.insights_focus_factors_coverage(1, 3), '1 plongée sur 3');
      expect(it.insights_focus_factors_coverage(1, 3), '1 immersione su 3');
      expect(fr.insights_focus_factors_coverage(0, 3), '0 plongée sur 3');
    });
  });

  group('Arabic and Hebrew use their own plural categories', () {
    test('Arabic gives the dual, few and many forms', () async {
      final ar = await load('ar');

      expect(
        ar.insights_focus_summary_allShown(2),
        'غطستان فقط لهما هذه القيمة، لذا تُعرض كلتاهما',
      );
      expect(
        ar.insights_focus_summary_allShown(11),
        '11 غطسةً فقط لها هذه القيمة، لذا تُعرض جميعها',
      );
      expect(
        ar.insights_focus_summary_allShown(100),
        '100 غطسة فقط لها هذه القيمة، لذا تُعرض جميعها',
      );
      expect(ar.insights_focus_factors_coverage(1, 2), '1 من غطستين');
      expect(ar.insights_focus_factors_coverage(5, 11), '5 من 11 غطسةً');
      expect(ar.insights_focus_factors_coverage(5, 100), '5 من 100 غطسة');
    });

    test('Hebrew gives the dual form', () async {
      final he = await load('he');

      expect(
        he.insights_focus_summary_allShown(2),
        'רק לשתי צלילות יש ערך זה, ולכן שתיהן מוצגות',
      );
      expect(he.insights_focus_factors_coverage(1, 2), '1 מתוך שתי צלילות');
    });
  });
}
