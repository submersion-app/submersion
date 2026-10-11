// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'kept_english_values.dart';

/// Guards the translated ARB files against values left identical to English.
///
/// `flutter gen-l10n` and `arb_parity_test.dart` only check that every key
/// exists in every locale, so a value copied from `app_en.arb` passes both and
/// ships English to that locale. Widget tests pin `Locale('en')`, so nothing
/// else notices either. Issue #2481 found 215 such keys after #2283's pass.
///
/// A value counts when it matches English ignoring case (so "Open circuit" for
/// "Open Circuit" is still English) and still holds at least two words once ICU
/// placeholders are removed, which leaves out single words such as "OK" and
/// bare unit symbols. Some values are correct as English (brand and course
/// names, unit abbreviations, loanwords a locale already uses); each is listed
/// with its reason in [keptEnglishValues].
void main() {
  final arbDir = p.join('lib', 'l10n', 'arb');

  Map<String, dynamic> load(String locale) =>
      json.decode(File(p.join(arbDir, 'app_$locale.arb')).readAsStringSync())
          as Map<String, dynamic>;

  final english = load('en');
  final locales =
      Directory(arbDir)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.endsWith('.arb') && name != 'app_en.arb')
          .map((name) => name.substring(4, name.length - 4))
          .toList()
        ..sort();
  final translated = {for (final locale in locales) locale: load(locale)};

  /// The words a reader sees, with `{name}` arguments and the
  /// `{name, plural,` / `{name, select,` heads removed.
  int wordCount(String value) {
    final text = value
        .replaceAll(RegExp(r'\{\w+\}'), ' ')
        .replaceAll(RegExp(r'\{\w+,\s*(plural|select)\s*,'), ' ');
    return RegExp('[A-Za-z]+').allMatches(text).length;
  }

  /// Every `key@locale` pair whose value is English, with at least two words.
  Set<String> englishPairs() {
    final pairs = <String>{};
    english.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      if (wordCount(value) < 2) return;
      final lower = value.toLowerCase();
      for (final locale in locales) {
        final local = translated[locale]![key];
        if (local is String && local.toLowerCase() == lower) {
          pairs.add('$key@$locale');
        }
      }
    });
    return pairs;
  }

  final pairs = englishPairs();

  bool isKept(String pair) {
    final key = pair.split('@').first;
    return keptEnglishValues.containsKey(key) ||
        keptEnglishValues.containsKey(pair);
  }

  test('no translated locale shows an English value it should translate', () {
    final offenders = pairs.where((pair) => !isKept(pair)).toList()..sort();
    expect(
      offenders,
      isEmpty,
      reason:
          'These values are identical to app_en.arb. Translate them, or add '
          'the key (or key@locale) to keptEnglishValues with the reason it '
          'stays English:\n${offenders.join('\n')}',
    );
  });

  test('every kept-English entry still names an English value', () {
    final stale = keptEnglishValues.keys.where((entry) {
      if (entry.contains('@')) return !pairs.contains(entry);
      return !pairs.any((pair) => pair.split('@').first == entry);
    }).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'These keptEnglishValues entries no longer match an English value in '
          'any locale; remove them:\n${stale.join('\n')}',
    );
  });

  test('every kept-English entry gives a reason', () {
    final blank = keptEnglishValues.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    expect(blank, isEmpty);
  });
}
