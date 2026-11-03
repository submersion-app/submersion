import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every editable record must be writable by an agent before release (spec,
/// "Coverage and release gate"), so a repository's create, update and delete
/// methods are each accounted for: reached by a write entity, or listed in
/// the baseline as not reached yet. The baseline only shrinks. A new method
/// that a write entity does not reach fails here, which is what keeps "any
/// record" true.
///
/// After covering a method, move it to [covered] and regenerate the baseline:
/// `UPDATE_AGENT_WRITE_BASELINE=1 flutter test
/// test/architecture/agent_write_coverage_test.dart`
void main() {
  const baselinePath = 'test/architecture/agent_write_coverage_baseline.txt';

  /// `repository file:method`, and the write entity that reaches it.
  const covered = <String, String>{
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createDive':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateFields':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkShiftDiveTimes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkDeleteDives':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkSetSite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddDiveTypes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveDiveTypes':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:createBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:updateFields':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:deleteBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkAddBuddies':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkRemoveBuddies':
        'dives',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:createSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:deleteSite':
        'sites',
  };

  /// A `Future` method on a repository whose name says it writes. The return
  /// type may sit on the line above the name.
  final writeMethod = RegExp(
    r'^\s*Future<.*>\s+(?:\n\s*)?'
    r'((?:create|add|insert|update|set|save|delete|remove|upsert|bulk|merge)'
    r'(?:[A-Z]\w*)?)\s*[(<]',
    multiLine: true,
  );

  Set<String> scanRepositories() {
    final found = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/data/repositories/')) continue;
      for (final match in writeMethod.allMatches(entity.readAsStringSync())) {
        found.add('$path:${match.group(1)}');
      }
    }
    return found;
  }

  Set<String> readBaseline() => File(baselinePath)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();

  test('every repository write is covered or in the baseline', () {
    final found = scanRepositories();
    if (Platform.environment['UPDATE_AGENT_WRITE_BASELINE'] == '1') {
      final lines = found.difference(covered.keys.toSet()).toList()..sort();
      File(baselinePath).writeAsStringSync('${lines.join('\n')}\n');
    }

    final unaccounted = found
        .difference(covered.keys.toSet())
        .difference(readBaseline());

    expect(
      unaccounted,
      isEmpty,
      reason:
          'A repository gained a write no agent can reach. Add a change set '
          'entity for it and list it in covered.',
    );
  });

  test('the baseline names no method that has gone or been covered', () {
    final found = scanRepositories();

    expect(readBaseline().difference(found), isEmpty);
    expect(readBaseline().intersection(covered.keys.toSet()), isEmpty);
  });

  test('every covered method exists', () {
    expect(covered.keys.toSet().difference(scanRepositories()), isEmpty);
  });
}
