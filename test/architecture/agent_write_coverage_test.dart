import 'dart:io';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

part 'agent_write_coverage_covered.dart';
part 'agent_write_coverage_exempt.dart';

/// The repository folders the covered and exempt maps name methods in.
const gear = 'lib/features/equipment/data/repositories';
const passports = 'lib/features/cylinder_passports/data/repositories';
const trips = 'lib/features/trips/data/repositories';
const checklists = 'lib/features/checklists/data/repositories';
const divers = 'lib/features/divers/data/repositories';
const certs = 'lib/features/certifications/data/repositories';
const courses = 'lib/features/courses/data/repositories';
const planner = 'lib/features/planner/data/repositories';
const safety = 'lib/features/safety/data/repositories';
const diveLog = 'lib/features/dive_log/data/repositories';
const media = 'lib/features/media/data/repositories';

/// Every editable record must be writable by an agent before release (spec,
/// "Coverage and release gate"), so every repository method whose name says
/// it writes ([isWriteName]: create, update and delete, and rename, assign,
/// link, reorder and the rest) is accounted for: reached by a write entity,
/// or listed in the baseline as not reached yet. The baseline only shrinks. A new method
/// that a write entity does not reach fails here, which is what keeps "any
/// record" true.
///
/// After covering a method, add it to [covered] (in
/// agent_write_coverage_covered.dart) and regenerate the baseline:
/// `UPDATE_AGENT_WRITE_BASELINE=1 flutter test
/// test/architecture/agent_write_coverage_test.dart`
void main() {
  const baselinePath = 'test/architecture/agent_write_coverage_baseline.txt';

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
      'startSession',
      'completeSession',
      'abortSession',
      'cloneTemplate',
      'dissolveSeries',
      'pack',
      'unpack',
      'splitTrack',
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

  /// Whether [method] is exempt, by name or with its whole repository file.
  bool isExempt(String method) =>
      exempt.containsKey(method) ||
      exempt.containsKey('${method.substring(0, method.lastIndexOf(':'))}:*');

  test('every exempt entry names an existing write and a reason', () {
    final found = scanRepositories();
    for (final MapEntry(:key, :value) in exempt.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
      if (key.endsWith(':*')) {
        final file = key.substring(0, key.length - 1);
        expect(found.any((m) => m.startsWith(file)), isTrue, reason: key);
      } else {
        expect(found, contains(key));
      }
    }
  });

  test('no method is both covered and exempt', () {
    expect(covered.keys.where(isExempt), isEmpty);
  });

  test('every repository write is covered or in the baseline', () {
    final found = scanRepositories().where((m) => !isExempt(m)).toSet();
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
    expect(readBaseline().where(isExempt), isEmpty);
  });

  test('every covered method exists', () {
    expect(covered.keys.toSet().difference(scanRepositories()), isEmpty);
  });

  // Every write is covered or exempt, so a new one fails here until it is
  // given a change set entity or a reason.
  test('the baseline is empty', () {
    expect(readBaseline(), isEmpty);
  });

  test('every covered method names an entity an agent can write', () {
    final writable = {
      for (final entry in WriteCatalog(RecordRepositories()).all) entry.name,
    };

    expect(covered.values.toSet().difference(writable), isEmpty);
  });

  test('every covered method is called by a writer, or through a call one '
      'makes', () {
    final writers = [
      for (final file in Directory(
        'lib/features/agent_access/data/writes',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart')) file.readAsStringSync(),
    ].join('\n');
    bool named(String? name) =>
        name != null && RegExp('\\b$name\\b').hasMatch(writers);

    final unreached = [
      for (final key in covered.keys)
        if (!named(key.split(':').last) && !named(reachedThrough[key])) key,
    ];

    expect(unreached, isEmpty);
    expect(
      reachedThrough.keys.toSet().difference(covered.keys.toSet()),
      isEmpty,
    );
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
  'start',
  'complete',
  'abort',
  'clone',
  'dissolve',
  'pack',
  'unpack',
  'split',
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
