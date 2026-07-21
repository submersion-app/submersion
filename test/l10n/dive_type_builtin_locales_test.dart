import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Locale coverage for the built-in dive type names added in issue #643.
///
/// `dive_type_display_test.dart` proves the lookup resolves; this proves every
/// supported locale actually carries a value, so a locale added later cannot
/// silently fall back to English getters.
void main() {
  const locales = [
    'en',
    'de',
    'es',
    'fr',
    'it',
    'nl',
    'pt',
    'hu',
    'zh',
    'ar',
    'he',
  ];

  Set<String> seededBuiltInIds() {
    final matches = RegExp(
      r"SELECT\s+'([a-z_]+)'",
    ).allMatches(kSeedBuiltInDiveTypesSql);
    return {for (final m in matches) m.group(1)!};
  }

  test('the supported locale list matches AppLocalizations', () {
    // Guards the loop below: a newly supported locale must be added here or
    // this test fails rather than silently skipping it.
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      locales.toSet(),
    );
  });

  for (final code in locales) {
    test('$code has a non-empty name for every built-in dive type', () {
      final l10n = lookupAppLocalizations(Locale(code));
      for (final id in seededBuiltInIds()) {
        final name = builtInDiveTypeName(l10n, id);
        expect(name, isNotNull, reason: '$code is missing a name for "$id"');
        expect(
          name!.trim(),
          isNotEmpty,
          reason: '$code has a blank name for "$id"',
        );
      }
    });
  }

  test('every locale file carries all fifteen keys', () {
    final expected = {
      for (final id in seededBuiltInIds()) 'diveType_builtin_${_camel(id)}': id,
    };
    expect(expected, hasLength(15));

    for (final code in locales) {
      final arb =
          json.decode(File('lib/l10n/arb/app_$code.arb').readAsStringSync())
              as Map<String, dynamic>;
      final missing = expected.keys.where((k) => !arb.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'app_$code.arb is missing $missing');
    }
  });

  test('German translates every built-in rather than echoing English', () {
    // The reported symptom in #643 was English text under a German UI, so this
    // asserts the values actually differ from the seeded English literals.
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));

    // 'cavern' is deliberately kept as the English loanword in German, matching
    // how the training agencies use it.
    const intentionalLoanwords = {'cavern'};

    for (final id in seededBuiltInIds()) {
      if (intentionalLoanwords.contains(id)) continue;
      expect(
        builtInDiveTypeName(de, id),
        isNot(builtInDiveTypeName(en, id)),
        reason: 'German "$id" still reads like the English source',
      );
    }
  });
}

String _camel(String slug) {
  final parts = slug.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
