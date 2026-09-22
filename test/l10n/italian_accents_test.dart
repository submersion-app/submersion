import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Italian translations against accents being dropped (#2244).
///
/// Part of `app_it.arb` was written with the accents stripped: `profondita`
/// for `profondità`, `piu` for `più`, `puo` for `può`. The same words are
/// spelled correctly elsewhere in the same file, so this is a typo class
/// rather than a house style, and it is worth a standing guard.
void main() {
  final arb =
      jsonDecode(File('lib/l10n/arb/app_it.arb').readAsStringSync())
          as Map<String, dynamic>;

  final italian = <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };

  /// Words whose bare spelling is not an Italian word at all, so every
  /// occurrence outside [exemptions] is a dropped accent.
  const alwaysAccented = <String, String>{
    'attivita': 'attività',
    'densita': 'densità',
    'difficolta': 'difficoltà',
    'disponibilita': 'disponibilità',
    'gia': 'già',
    'giu': 'giù',
    'influenzera': 'influenzerà',
    'intensita': 'intensità',
    'localita': 'località',
    'modalita': 'modalità',
    'passera': 'passerà',
    'piu': 'più',
    'profondita': 'profondità',
    'puo': 'può',
    'quantita': 'quantità',
    'tossicita': 'tossicità',
    'unita': 'unità',
    'validita': 'validità',
    'varieta': 'varietà',
    'velocita': 'velocità',
    'verra': 'verrà',
    'visibilita': 'visibilità',
  };

  /// Keys where the bare spelling is a different, correct Italian word.
  ///
  /// `unita` is the past participle of `unire` (merged), `giu` abbreviates
  /// `giugno`, and `passera` is the flounder rather than the future of
  /// `passare`. `necessita` (third person of `necessitare`) is deliberately
  /// absent from [alwaysAccented]: every use in this file is the verb, and
  /// the noun `necessità` never appears in the app.
  const exemptions = <String, Set<String>>{
    'diveComputer_merge_snackbar': {'unita'},
    'diveLog_combine_snackbar': {'unita'},
    'diveLog_consolidate_snackbar': {'unita'},
    'diveLog_sources_separateDialog_body': {'unita'},
    'gpsTrack_colorMode_uniform': {'unita'},
    'species_peacock_flounder_name': {'passera'},
    'statistics_timePatterns_month_jun': {'giu'},
  };

  /// Dart's `\b` is ASCII-only, so `\bpiu\b` matches inside `più`. Bound the
  /// match on the accented Latin range instead.
  RegExp wordPattern(String word) =>
      RegExp("(?<![A-Za-zÀ-ÿ'])$word(?![A-Za-zÀ-ÿ'])", caseSensitive: false);

  test('no Italian value drops the accent from an always-accented word', () {
    final failures = <String>[];
    for (final entry in italian.entries) {
      for (final word in alwaysAccented.keys) {
        if (exemptions[entry.key]?.contains(word) ?? false) continue;
        if (wordPattern(word).hasMatch(entry.value)) {
          failures.add(
            '${entry.key}: "${entry.value}" '
            'should spell $word as ${alwaysAccented[word]}',
          );
        }
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          '${failures.length} Italian strings are missing an accent:\n'
          '${failures.join('\n')}',
    );
  });

  /// Keys where a bare `e` was written for the verb `è`. The two are
  /// different words ("and" against "is"), so a general sweep cannot find
  /// them; these are the ones #2244 turned up, pinned so they stay fixed.
  const copulaKeys = <String>[
    'diveLog_equipmentPicker_allSpare',
    'equipment_list_emptyState_serviceDueUpToDate',
    'gasCalculators_mnd_infoContent',
    'gasCalculators_mnd_o2Narcotic',
    'media_diveScan_accessDenied',
    'settings_decompression_o2Narcotic',
    'settings_storage_resetDialog_backupFailed',
    'tags_manage_nameRequired',
  ];

  test('strings that state a fact use the accented copula è', () {
    final failures = <String>[];
    for (final key in copulaKeys) {
      final value = italian[key];
      if (value == null) {
        failures.add('$key: missing from app_it.arb');
      } else if (!value.contains('è')) {
        failures.add('$key: "$value" should use è, not a bare e');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
