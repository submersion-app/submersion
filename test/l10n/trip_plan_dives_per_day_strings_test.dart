import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// #2878: the Plan row on the trip Prepare overview read "1 dives/day",
/// because `trips_overview_plan_divesPerDay` was a plain `{count} dives/day`
/// string rather than a plural. Every locale now picks its own form for a
/// target of one dive a day.
void main() {
  Future<AppLocalizations> load(String languageCode) =>
      AppLocalizations.delegate.load(Locale(languageCode));

  // languageCode: (one dive a day, three dives a day)
  const expected = {
    'en': ('1 dive/day', '3 dives/day'),
    'ar': ('غوصة واحدة/يوم', '3 غوصات/يوم'),
    'de': ('1 Tauchgang/Tag', '3 Tauchgänge/Tag'),
    'es': ('1 inmersión/día', '3 inmersiones/día'),
    'fr': ('1 plongée/jour', '3 plongées/jour'),
    'he': ('צלילה אחת ליום', '3 צלילות ליום'),
    'hu': ('1 merülés/nap', '3 merülés/nap'),
    'it': ('1 immersione/giorno', '3 immersioni/giorno'),
    'nl': ('1 duik/dag', '3 duiken/dag'),
    'pt': ('1 mergulho/dia', '3 mergulhos/dia'),
    'zh': ('每天 1 次潜水', '每天 3 次潜水'),
  };

  test('every shipped locale is covered', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      expected.keys.toSet(),
    );
  });

  for (final MapEntry(key: code, value: (one, three)) in expected.entries) {
    test('$code agrees with its own count', () async {
      final l10n = await load(code);

      expect(l10n.trips_overview_plan_divesPerDay(1), one);
      expect(l10n.trips_overview_plan_divesPerDay(3), three);
    });
  }
}
