import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A query can read a cache of engine verdicts the SQL cannot compute: the
/// computed deco verdicts `deco` reads (#4461) and the service verdicts
/// `serviceDue` reads (#2365). A reader that runs one before its writer has
/// mirrored the engine answers from an empty or stale cache, silently. Five
/// readers were missed when `deco` began reading its cache, so this guard
/// makes the omission a test failure rather than a bug report: every file
/// that reads a live dive filter or compiles a query must wait through one
/// of the cache helpers, or say here why it need not.
void main() {
  /// Files that read a filter or compile a query without waiting, with the
  /// reason none of their queries can read a verdict cache before it is
  /// written.
  const exempt = <String, String>{
    'lib/features/connections/presentation/providers/connections_timeline_provider.dart':
        'reads the filter\'s date range to draw the timeline, runs no query',
  };

  /// Reading a live filter a diver can point at a verdict, or compiling a
  /// query that may name one.
  final reads = RegExp(
    r'ref\.watch\(\s*(diveFilterProvider|insightsFilterProvider|'
    r'connectionsFilterProvider)\b|\bcompileQuery\(|\bcompileDiveFilter\(',
  );

  /// Any of the ways a reader waits for the caches its query reads.
  final waits = RegExp(
    r'\b(awaitQueryCachesIfRead|awaitAndFollowQueryCaches|'
    r'awaitInsightsFilterCaches|awaitQueryCachesIfReadFromWidget|'
    r'prepareQueryCachesFor|_awaitQueryCaches|_keepAliveWithExpiry|'
    r'_awaitFilterCaches)\b',
  );

  /// Providers run the app's queries; widgets that watch a filter only show
  /// it, and the data layer that compiles a query cannot wait (its callers
  /// do).
  Iterable<File> sources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.replaceAll(r'\', '/').contains('/presentation/providers/') &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart'),
      );

  String code(File f) => [
    for (final line in f.readAsLinesSync())
      if (!line.trimLeft().startsWith('//')) line,
  ].join('\n');

  test('every reader of a dive filter or compiled query waits for the '
      'verdict caches', () {
    final offenders = <String>[];
    for (final file in sources()) {
      final path = file.path.replaceAll(r'\', '/');
      if (exempt.containsKey(path)) continue;
      final text = code(file);
      if (reads.hasMatch(text) && !waits.hasMatch(text)) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'wait for the caches the query reads (awaitQueryCachesIfRead, '
          'awaitAndFollowQueryCaches or prepareQueryCachesFor in '
          'lib/features/query/presentation/providers/query_cache_awaits.dart), '
          'or add the file to the exemptions with the reason it need not',
    );
  });

  test('every exemption still applies', () {
    // A stale exemption is how a guard quietly stops guarding.
    for (final entry in exempt.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        reads.hasMatch(code(file)),
        isTrue,
        reason:
            '${entry.key} is exempt as "${entry.value}" but no longer reads '
            'a filter or compiles a query; remove it from the exemptions',
      );
    }
  });
}
