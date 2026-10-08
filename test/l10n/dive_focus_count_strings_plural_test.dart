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
        '1 of 1 dive, group average G vs O overall',
        '2 of 3 dives, group average G vs O overall',
      ),
      'ar': (
        '1 من غطسة واحدة، متوسط المجموعة G مقابل O إجمالاً',
        '2 من 3 غطسات، متوسط المجموعة G مقابل O إجمالاً',
      ),
      'de': (
        '1 von 1 Tauchgang, Gruppendurchschnitt G gegenüber O insgesamt',
        '2 von 3 Tauchgängen, Gruppendurchschnitt G gegenüber O insgesamt',
      ),
      'es': (
        '1 de 1 inmersión, media del grupo G frente a O en total',
        '2 de 3 inmersiones, media del grupo G frente a O en total',
      ),
      'fr': (
        '1 plongée sur 1, moyenne du groupe G contre O au total',
        '2 plongées sur 3, moyenne du groupe G contre O au total',
      ),
      'he': (
        '1 מתוך צלילה אחת, ממוצע הקבוצה G לעומת O בסך הכול',
        '2 מתוך 3 צלילות, ממוצע הקבוצה G לעומת O בסך הכול',
      ),
      'hu': (
        '1 / 1 merülés, csoportátlag G, összesen O',
        '2 / 3 merülés, csoportátlag G, összesen O',
      ),
      'it': (
        '1 immersione su 1, media del gruppo G contro O complessiva',
        '2 immersioni su 3, media del gruppo G contro O complessiva',
      ),
      'nl': (
        '1 van 1 duik, groepsgemiddelde G tegenover O in totaal',
        '2 van 3 duiken, groepsgemiddelde G tegenover O in totaal',
      ),
      'pt': (
        '1 de 1 mergulho, média do grupo G contra O no total',
        '2 de 3 mergulhos, média do grupo G contra O no total',
      ),
      'zh': ('1 次潜水中的 1 次，组内平均 G，总体 O', '3 次潜水中的 2 次，组内平均 G，总体 O'),
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
