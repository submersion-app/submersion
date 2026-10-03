// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #2479: French wrote the no-decompression
/// limit (NDL) as "DTR", short for "duree totale de remontee", which is the
/// time to surface (TTS). Two TTS keys also said "TDR" while the rest of the
/// file said "TTS". French keeps both acronyms as the English ones.
void main() {
  late AppLocalizations fr;

  setUpAll(() {
    fr = lookupAppLocalizations(const Locale('fr'));
  });

  Map<String, String> readArb(String locale) {
    final arb =
        json.decode(
              File(
                p.join('lib', 'l10n', 'arb', 'app_$locale.arb'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    return {
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  for (final acronym in const ['NDL', 'TTS']) {
    test('every French string whose English says $acronym also says it', () {
      final en = readArb('en');
      final frArb = readArb('fr');
      final word = RegExp('\\b$acronym\\b');

      final offenders = [
        for (final entry in en.entries)
          if (word.hasMatch(entry.value) &&
              frArb[entry.key] != null &&
              !word.hasMatch(frArb[entry.key]!))
            '${entry.key} = ${frArb[entry.key]}',
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'French must name this metric $acronym, as the rest of the '
            'file does. Offending keys:\n${offenders.join('\n')}',
      );
    });
  }

  test('no French string uses DTR or TDR', () {
    final word = RegExp(r'\b(DTR|TDR)\b');
    final offenders = [
      for (final entry in readArb('fr').entries)
        if (word.hasMatch(entry.value)) '${entry.key} = ${entry.value}',
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'DTR (duree totale de remontee) is the time to surface, not the '
          'NDL, and French writes that metric as TTS. Offending keys:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the planner, tooltip and surface interval labels read NDL and TTS', () {
    expect(fr.diveLog_detail_collapsed_ndl('12 min'), 'NDL : 12 min');
    expect(fr.diveLog_tooltip_ndl, 'NDL');
    expect(fr.diveLog_tooltip_tts, 'TTS');
    expect(fr.divePlanner_label_ndl, 'NDL');
    expect(fr.divePlanner_label_tts, 'TTS');
    expect(
      fr.surfaceInterval_result_ndlForSecondDive,
      'NDL pour la 2e plongée',
    );
    expect(fr.surfaceInterval_result_ndlMinutes(42), '42 min NDL');
    expect(
      fr.surfaceInterval_aboutTissueLoading_body,
      contains('limite de non-décompression (NDL)'),
    );
  });
}
