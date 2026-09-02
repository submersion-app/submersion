import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every source file holding aggregate SQL over `dives`.
///
/// A query in one of these files that neither applies `DiveStatsScope` nor
/// carries an explicit `stats-scope-exempt` marker is a bug: someone added an
/// aggregate without deciding whether an excluded dive should count.
///
/// This exists because the behavioural suite can only test the queries someone
/// remembered to add to it. The rule it guards decayed once already: the
/// gauge-mode exclusion was hand-copied into seven queries with nothing
/// ensuring an eighth would get it.
const _censusFiles = <String>[
  'lib/features/statistics/data/repositories/statistics_repository.dart',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart',
  'lib/features/buddies/data/repositories/buddy_repository.dart',
  'lib/features/dive_sites/data/repositories/site_repository_impl.dart',
  'lib/features/trips/data/repositories/trip_repository.dart',
  'lib/features/dive_centers/data/repositories/dive_center_repository.dart',
  'lib/features/tags/data/repositories/tag_repository.dart',
  'lib/features/dive_types/data/repositories/dive_type_repository.dart',
  'lib/features/dive_roles/data/repositories/dive_role_repository.dart',
  'lib/features/divers/data/repositories/diver_repository.dart',
  'lib/features/marine_life/data/repositories/seen_species_repository.dart',
  'lib/features/marine_life/data/repositories/species_repository.dart',
  'lib/features/equipment/data/repositories/equipment_repository_impl.dart',
  'lib/features/courses/data/repositories/course_repository.dart',
  'lib/features/courses/data/repositories/course_requirement_repository.dart',
];

final _readsDives = RegExp(
  r'\b(?:FROM|JOIN)\s+dives\b|\bFROM\s+dive_(?:buddies|tags|dive_types)\b',
  caseSensitive: false,
);

/// Splits [source] into one chunk per class member.
///
/// Method granularity, not per-statement: the scope is threaded the way the
/// surrounding code threads its filter, as a fragment built once at the top of
/// a method and interpolated into several statements. A per-statement census
/// would flag every one of those as unscoped.
List<String> _memberChunks(String source) {
  final starts = <int>[];
  final lines = source.split('\n');
  final offsets = <int>[];
  var off = 0;
  for (final l in lines) {
    offsets.add(off);
    off += l.length + 1;
  }
  // A member starts at exactly two spaces of indent with an identifier,
  // annotation, or type. Anchoring on the leading character keeps
  // continuation lines like `  }) async {` from splitting a method in half,
  // which would hide the scope fragment built above the SQL.
  final member = RegExp(r'^  [A-Za-z_@][^\n]*[({]\s*$');
  final comment = RegExp(r'^\s*(///|//|@)');
  for (var i = 0; i < lines.length; i++) {
    if (!member.hasMatch(lines[i])) continue;
    // Walk back over the member's own doc comment and annotations, so a
    // `stats-scope-exempt` marker written above the signature belongs to the
    // member it describes rather than to the one before it.
    var start = i;
    while (start > 0 && comment.hasMatch(lines[start - 1])) {
      start--;
    }
    starts.add(offsets[start]);
  }
  if (starts.isEmpty) return [source];
  final chunks = <String>[source.substring(0, starts.first)];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : source.length;
    chunks.add(source.substring(starts[i], end));
  }
  return chunks;
}

({int scanned, List<String> offenders}) _audit() {
  final offenders = <String>[];
  var scanned = 0;

  for (final path in _censusFiles) {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$path is in the census list but does not exist. If it moved, '
          'update _censusFiles rather than deleting the entry.',
    );

    for (final chunk in _memberChunks(file.readAsStringSync())) {
      if (!_readsDives.hasMatch(chunk)) continue;
      scanned++;

      // Only two things count as applying the scope: naming DiveStatsScope,
      // or calling StatisticsRepository's own `_diveFilter` wrapper, which
      // emits it unconditionally.
      //
      // A bare `excluded_from_stats` mention deliberately does NOT count.
      // Hand-writing that one column satisfies the letter of the rule while
      // silently missing `is_planned = 0` (and, on a gas query, the gas flag
      // and the gauge-mode rule), which is exactly the partial-copy rot this
      // census exists to prevent. Go through the helper or mark the query
      // exempt; there is no third option.
      final applied =
          chunk.contains('DiveStatsScope') || chunk.contains('_diveFilter(');
      final exempt = chunk.contains('stats-scope-exempt');

      if (!applied && !exempt) {
        final signature = chunk.split('\n').first.trim();
        final line = chunk
            .split('\n')
            .firstWhere((l) => _readsDives.hasMatch(l), orElse: () => '')
            .trim();
        offenders.add('  $path\n    in: $signature\n    sql: $line');
      }
    }
  }
  return (scanned: scanned, offenders: offenders);
}

void main() {
  test('every dives aggregate applies the scope or is marked exempt', () {
    final result = _audit();

    expect(
      result.offenders,
      isEmpty,
      reason:
          'These queries read `dives` but neither apply DiveStatsScope nor '
          'carry a `stats-scope-exempt` marker.\n\n'
          'Decide which this query is:\n'
          '  - Descriptive (a number the diver reads as a statistic): apply\n'
          '    the scope, e.g. \${DiveStatsScope.and(alias: "d")}.\n'
          '  - Operational (gear wear, course credit, a deletion guard, a\n'
          '    displayed list): add a `// stats-scope-exempt: <reason>`\n'
          '    comment saying why.\n\n'
          'Offenders:\n${result.offenders.join('\n')}',
    );
  });

  test('the census actually sees the queries it claims to guard', () {
    // A census that silently matches nothing looks exactly like one that
    // passes correctly. Pin the floor so a broken regex or a renamed file
    // fails loudly instead of quietly guarding an empty set.
    final result = _audit();
    expect(
      result.scanned,
      greaterThan(25),
      reason:
          'the census matched only \${result.scanned} dives-reading members, '
          'which is far fewer than this codebase has. The regex or the file '
          'list is broken, and the guard above is passing vacuously.',
    );
  });
}
