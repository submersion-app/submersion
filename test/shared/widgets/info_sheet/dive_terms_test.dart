import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';

/// Words and phrases the sheets never use: they explain, they do not advise.
final adviceWords = RegExp(
  r"\b(you should|aim for|stay under|safe|it's fine)\b",
  caseSensitive: false,
);

/// Counts sentences the way the copy caps count them: each ". ", "? " or
/// "! " ends one, and so does the final stop.
int sentenceCount(String text) {
  final trimmed = text.trim();
  final inner = RegExp(r'[.?!] ').allMatches(trimmed).length;
  final last = RegExp(r'[.?!]$').hasMatch(trimmed) ? 1 : 0;
  return inner + last;
}

void main() {
  const metric = UnitFormatter(AppSettings());
  final en = lookupAppLocalizations(const Locale('en'));

  test('every term has a non-empty label and body in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final term in DiveTerm.values) {
        final entry = diveTermEntry(l10n, metric, term);
        expect(entry.term.trim(), isNotEmpty, reason: '$locale $term label');
        expect(entry.body.trim(), isNotEmpty, reason: '$locale $term body');
      }
    }
  });

  test('bodies are at most two sentences in English', () {
    for (final term in DiveTerm.values) {
      final body = diveTermEntry(en, metric, term).body;
      expect(body, isNot(contains('e.g.')), reason: '$term');
      expect(sentenceCount(body), lessThanOrEqualTo(2), reason: '$term: $body');
    }
  });

  test('no body gives advice', () {
    for (final term in DiveTerm.values) {
      final body = diveTermEntry(en, metric, term).body;
      expect(adviceWords.hasMatch(body), isFalse, reason: '$term: $body');
    }
  });

  test("ascent rate uses the diver's depth unit", () {
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    final metricBody = diveTermEntry(en, metric, DiveTerm.ascentRate).body;
    final imperialBody = diveTermEntry(en, imperial, DiveTerm.ascentRate).body;

    expect(metricBody, contains('9m/min'));
    expect(imperialBody, contains('30ft/min'));
    expect(imperialBody, isNot(contains('m/min')));
  });

  test('diveTermEntries keeps order and drops duplicates', () {
    final entries = diveTermEntries(en, metric, const [
      DiveTerm.otu,
      DiveTerm.cns,
      DiveTerm.otu,
    ]);

    expect(entries.map((e) => e.term).toList(), [
      diveTermEntry(en, metric, DiveTerm.otu).term,
      diveTermEntry(en, metric, DiveTerm.cns).term,
    ]);
  });
}
