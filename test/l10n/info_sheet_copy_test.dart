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
  final english =
      json.decode(
            File(p.join('lib', 'l10n', 'arb', 'app_en.arb')).readAsStringSync(),
          )
          as Map<String, dynamic>;

  /// Sentences counted the way the caps count them: each ". ", "? " or "! "
  /// ends one, and so does a final stop.
  int sentences(String text) {
    final trimmed = text.trim();
    final inner = RegExp(r'[.?!] ').allMatches(trimmed).length;
    final last = RegExp(r'[.?!]$').hasMatch(trimmed) ? 1 : 0;
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

  test('every info sheet string stays within its sentence cap', () {
    final over = <String>[];
    for (final key in infoKeys) {
      for (final MapEntry(key: suffix, value: cap) in caps.entries) {
        if (!key.endsWith(suffix)) continue;
        final count = sentences(english[key] as String);
        if (count > cap) over.add('$key: $count > $cap');
      }
    }
    expect(over, isEmpty);
  });

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
