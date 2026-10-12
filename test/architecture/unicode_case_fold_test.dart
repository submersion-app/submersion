import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// Case-insensitive text matching in SQL goes through `unicode_lower`, and
/// every connection the app opens registers it (issue #3032).
///
/// SQLite's built-in `lower()` / `upper()` and drift's `.lower()` fold ASCII
/// only, so "Éponge" never met "éponge": imports minted twin species, tags
/// and buddies, and searches missed any name with an accented capital. Every
/// offender was converted; this scan is the ratchet.
///
/// The allowlist holds the folds that must stay ASCII, each with its reason.
void main() {
  bool isGenerated(String path) =>
      path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

  // Whole files where the built-in fold is required, not an oversight.
  const exemptFiles = {
    // The tags unique index and the collapse that runs before it is built.
    // An index expression cannot call an app function: the function is
    // absent from any connection the app did not open.
    'lib/core/database/tag_uniqueness.dart',
  };
  // Migrations are history: they ran against the data of their day, and a
  // migration test opens its connection with its own fixture setup.
  const exemptDirs = ['lib/core/database/migrations/'];

  // Individual folds that are ASCII by construction.
  final allowed = [
    // A random id rendered as lowercase hex.
    RegExp(r'lower\(\s*hex\(', caseSensitive: false),
    // A Bluetooth address: hex digits and colons.
    RegExp(r'UPPER\(TRIM\(c\.address\)\)'),
  ];

  final sqlFold = RegExp(r'\b(lower|upper)\s*\(', caseSensitive: false);
  final driftFold = RegExp(r'\.(lower|upper)\(\)');

  Iterable<(String, File)> libFiles() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      yield (path, entity);
    }
  }

  test('no ASCII-only case fold in SQL or a drift expression', () {
    final offenders = <String>[];
    for (final (path, file) in libFiles()) {
      if (exemptFiles.contains(path)) continue;
      if (exemptDirs.any(path.startsWith)) continue;
      final masked = MaskedSource(file.readAsStringSync());
      for (final m in sqlFold.allMatches(masked.text)) {
        final rest = masked.text.substring(m.start);
        if (allowed.any((a) => a.matchAsPrefix(rest) != null)) continue;
        // `.lower()` is reported by the drift scan below.
        if (m.start > 0 && masked.text[m.start - 1] == '.') continue;
        offenders.add('$path:${masked.lineOf(m.start)}: ${m[0]}');
      }
      for (final m in driftFold.allMatches(masked.code)) {
        offenders.add('$path:${masked.lineOf(m.start)}: ${m[0]}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Fold case with unicode_lower(...) in SQL, or .unicodeLower() on a '
          'drift expression (lib/core/database/app_sql_functions.dart):\n'
          '${offenders.join('\n')}',
    );
  });

  test('every connection the app opens registers the app SQL functions', () {
    final construction = RegExp(r'\bNativeDatabase(\.\w+)?\(');
    final offenders = <String>[];
    for (final (path, file) in libFiles()) {
      final masked = MaskedSource(file.readAsStringSync());
      for (final m in construction.allMatches(masked.code)) {
        final args = masked.code.substring(
          m.end,
          _closingParen(masked.code, m.end - 1),
        );
        if (!args.contains('setup:')) {
          offenders.add('$path:${masked.lineOf(m.start)}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Pass setup: applyMainDatabaseSetup / applyConnectionBasics, or '
          'registerAppSqlFunctions, so unicode_lower exists on the '
          'connection:\n${offenders.join('\n')}',
    );
  });
}

/// The offset of the parenthesis that closes the one at [open] in [code], or
/// the end of [code] when it never closes.
int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final unit = code[i];
    if (unit == '(') {
      depth++;
    } else if (unit == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length - 1;
}
