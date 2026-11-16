import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'source_mask.dart';

/// Searches and name sorts ignore accents as well as case (issue #4498).
///
/// A buddy saved as "Jérémie" sorted after "Joachim", and typing "jeremie"
/// found nothing, because a search compared `unicode_lower(...)` (case only)
/// and a sort compared `toLowerCase()` text by code unit, which puts every
/// accented letter after "z". Every offender was converted; these scans are
/// the ratchet.
void main() {
  bool isGenerated(String path) =>
      path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

  Iterable<(String, MaskedSource)> libSources() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      // Migrations are history, as in unicode_case_fold_test.dart.
      if (path.startsWith('lib/core/database/migrations/')) continue;
      yield (path, MaskedSource(entity.readAsStringSync()));
    }
  }

  test('lib/ is where the scans look', () {
    expect(
      File(p.join('lib', 'core', 'text', 'text_sort.dart')).existsSync(),
      isTrue,
      reason: 'a wrong working directory would make every scan pass',
    );
  });

  test('a search LIKE folds accents with search_fold', () {
    final sqlLike = RegExp(
      // One level of nested parentheses, for unicode_lower(COALESCE(x, '')).
      r'\bunicode_lower\s*\((?:[^()]|\([^()]*\))*\)\s+LIKE\b',
      caseSensitive: false,
    );
    final driftLike = RegExp(r'\.unicodeLower\(\)\s*\.\s*(contains|like)\(');
    final offenders = <String>[];
    for (final (path, masked) in libSources()) {
      for (final m in sqlLike.allMatches(masked.text)) {
        offenders.add('$path:${masked.lineOf(m.start)}: ${m[0]}');
      }
      for (final m in driftLike.allMatches(masked.code)) {
        offenders.add('$path:${masked.lineOf(m.start)}: ${m[0]}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Match a search with search_fold(column) LIKE ? (or '
          '.searchFold().contains(...)) and fold the needle with '
          'foldForSearch, so "jeremie" finds "Jérémie":\n'
          '${offenders.join('\n')}',
    );
  });

  test('names sort with the shared collator, not a lowercase compare', () {
    final lowerCompare = RegExp(
      // A lowercase compare, a lowercasing key helper, or a raw compare of
      // a name-like member, which also orders by code unit.
      r'\.toLowerCase\(\)\s*\.\s*compareTo\('
      r'|\blegacyNameKey\((?:[^()]|\([^()]*\))*\)\s*\.\s*compareTo\('
      r'|\.(?:name|label|title|displayName|commonName)!?\s*\.\s*compareTo\(',
    );
    // Raw compares of a name that is not a person's or a place's: an enum's
    // stored name, or a file name, where code-unit order is the intent. Each
    // entry exempts one expression in one file, so any other name sort in
    // the same file is still checked.
    const allowed = {
      // Backup file names carry a timestamp; their order is chronological.
      'lib/features/backup/data/services/cross_device_retention.dart':
          'a.name.compareTo(b.name)',
      // Garmin activity file names, staged in a stable order.
      'lib/features/universal_import/data/services/garmin_mtp_stager.dart':
          'a.name.compareTo(b.name)',
      // Enum names (`EquipmentType.name`, an exposure unit's key).
      'lib/features/equipment/presentation/providers/equipment_providers.dart':
          'a.type.name.compareTo(b.type.name)',
      'lib/features/equipment/domain/entities/exposure_unit.dart':
          'a.key.name.compareTo(b.key.name)',
    };
    final offenders = <String>[];
    for (final (path, masked) in libSources()) {
      final exempt = allowed[path];
      for (final m in lowerCompare.allMatches(masked.code)) {
        if (exempt != null) {
          // The exempt expression starts at the operand before the match.
          final start = masked.code.lastIndexOf(exempt, m.end);
          if (start != -1 &&
              start + exempt.length > m.start &&
              start <= m.start) {
            continue;
          }
        }
        offenders.add('$path:${masked.lineOf(m.start)}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Sort names with compareTextForSort, TextCollator or '
          'sortedByText (lib/core/text/text_sort.dart), which fold accents '
          'so "Jérémie" sorts before "Joachim":\n${offenders.join('\n')}',
    );
  });
}
