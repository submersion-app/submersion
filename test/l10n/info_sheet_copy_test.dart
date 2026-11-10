// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Holds every info sheet string to the length caps and the no-advice rule
/// from docs/design/specs/2026-11-09-card-info-icons-design.md.
///
/// Sheets explain what a card shows; they never tell the diver what to do in
/// the water, and they stay short enough to read at a glance.
void main() {
  Map<String, dynamic> arb(String locale) =>
      json.decode(
            File(
              p.join('lib', 'l10n', 'arb', 'app_$locale.arb'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  final english = arb('en');

  /// Every shipped locale, read from the ARB files on disk.
  final locales = [
    for (final file in Directory(p.join('lib', 'l10n', 'arb')).listSync())
      if (RegExp(r'app_(\w+)\.arb$').firstMatch(p.basename(file.path))
          case final match?)
        match.group(1)!,
  ]..sort();

  /// Sentences counted the way the caps count them: each ". ", "? ", "! "
  /// or Arabic "؟ " ends one, as does a Chinese "。" with text after it, and
  /// so does a final stop.
  int sentences(String text) {
    final trimmed = text.trim();
    final inner =
        RegExp(r'[.?!؟] ').allMatches(trimmed).length +
        RegExp(r'。(?=.)').allMatches(trimmed).length;
    final last = RegExp(r'[.?!؟。]$').hasMatch(trimmed) ? 1 : 0;
    return inner + last;
  }

  final advice = RegExp(
    r"\b(you should|aim for|stay under|safe|it's fine|make sure)\b",
    caseSensitive: false,
  );

  const caps = {'_summary': 2, '_body': 2, '_background': 3, '_howToUse': 4};

  final infoKeys = english.keys
      .where((k) => k.startsWith('info_') && !k.startsWith('@'))
      .toList();

  test('there are info sheet strings to check', () {
    expect(infoKeys.where((k) => k.endsWith('_summary')), isNotEmpty);
  });

  test('every locale is checked', () {
    expect(locales, hasLength(greaterThan(1)));
    expect(locales, contains('en'));
  });

  test('every info sheet string stays within its cap in every locale', () {
    final over = <String>[];
    for (final locale in locales) {
      final strings = arb(locale);
      for (final key in infoKeys) {
        final text = strings[key];
        if (text is! String) continue;
        for (final MapEntry(key: suffix, value: cap) in caps.entries) {
          if (!key.endsWith(suffix)) continue;
          final count = sentences(text);
          if (count > cap) over.add('$locale $key: $count > $cap');
        }
      }
    }
    expect(over, isEmpty);
  });

  // The advice and abbreviation checks below read English only: their word
  // lists are English, and the translations follow the English copy.

  test('no info sheet string gives diving advice', () {
    final offenders = [
      for (final key in infoKeys)
        if (advice.hasMatch(english[key] as String)) key,
    ];
    expect(offenders, isEmpty);
  });

  test('no info sheet string abbreviates with e.g.', () {
    final offenders = [
      for (final key in infoKeys)
        if ((english[key] as String).contains('e.g.')) key,
    ];
    expect(offenders, isEmpty);
  });
}
