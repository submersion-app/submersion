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

  /// A public `Future` method on a repository. The return type may sit on the
  /// line above the name. The type stops at `=` and at the end of its line, or
  /// on a line ending in `=>` it would run to that arrow and take the method
  /// the body calls on the next line for this one.
  final futureMethod = RegExp(
    r'^\s*Future<[^=;\n]*>\s+(?:\n\s*)?([a-z]\w*)\s*[(<]',
    multiLine: true,
  );

  Set<String> scanRepositories() {
    final found = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/data/repositories/')) continue;
      for (final match in futureMethod.allMatches(entity.readAsStringSync())) {
        final name = match.group(1)!;
        if (isWriteName(name)) found.add('$path:$name');
      }
    }
    return found;
  }

  test('a write is known by every verb repositories use for one', () {
    for (final name in [
      'createDive',
      'renameDiveRole',
      'assignDivesToTrip',
      'linkDiveToCourse',
      'unlinkDive',
      'reorderCylinders',
      'markAsServiced',
      'clearDefault',
      'replaceBuddyCertifications',
      'retireEquipment',
      'shareWith',
      'shiftDiveTimes',
      'fillNotesIfEmpty',
      'recordConnection',
    ]) {
      expect(isWriteName(name), isTrue, reason: name);
    }
    for (final name in [
      'getDiveById',
      'recordExists',
      'countDives',
      'watchAll',
      'partitionMediaForDiveDeletion',
    ]) {
      expect(isWriteName(name), isFalse, reason: name);
    }
  });

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

/// Whether a repository method's name says it writes. The verbs are the ones
/// repositories here use for a write, so a new method under any of them is
/// either reached by a write entity or listed in the baseline.
bool isWriteName(String name) =>
    !_readsNamedLikeWrites.contains(name) &&
    RegExp('^(?:${_writeVerbs.join('|')})(?:[A-Z]\\w*)?\$').hasMatch(name);

const _writeVerbs = [
  'create',
  'add',
  'insert',
  'update',
  'set',
  'save',
  'delete',
  'remove',
  'upsert',
  'bulk',
  'merge',
  'clear',
  'restore',
  'link',
  'unlink',
  'relink',
  'repoint',
  'apply',
  'replace',
  'rename',
  'reorder',
  'undo',
  'mark',
  'write',
  'assign',
  'reassign',
  'unassign',
  'fill',
  'shift',
  'retire',
  'share',
  'unshare',
  'record',
  'stamp',
  'promote',
  'archive',
  'unarchive',
  'toggle',
  'hide',
  'unhide',
  'move',
  'attach',
  'detach',
  'swap',
  'duplicate',
  'reset',
  'dismiss',
  'pin',
  'unpin',
  'purge',
  'prune',
  'wipe',
];

/// Methods whose name starts with a write verb but which only read.
const _readsNamedLikeWrites = {'recordExists'};
