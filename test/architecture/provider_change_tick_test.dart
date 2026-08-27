import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'provider_tick_scanner.dart';

/// Guards the project rule that a provider reading a table must self-invalidate
/// on that table's change tick (issue #974).
///
/// Writes reach the database through paths that bypass every notifier:
/// `DiveRepository.bulkDeleteDives` (used by `dive_merge_service` and
/// `dive_consolidation_service`), sync pulls applying remote deletions, and
/// repository-level bulk edits. None of them call `ref.invalidate` on a
/// provider's behalf, so a provider that does not subscribe serves a stale
/// cache until something unrelated happens to invalidate it.
///
/// This test does NOT check WHICH tick a provider subscribes to. When fixing a
/// failure, do not reach for the nearest tick: a junction read such as
/// `BuddyRepository.getDiveIdsForBuddy` lives on the buddy repository but goes
/// stale on a DIVES cascade delete, so it needs `watchDivesChanges()`.
///
/// Known limitation: this checks provider DECLARATIONS, not `Notifier` classes.
/// `DiveListNotifier`, `PaginatedDiveListNotifier`, and `TripListNotifier`
/// subscribe correctly with raw `.listen()` + `ref.onDispose` and are skipped
/// here, because their provider bodies construct a class rather than calling
/// repository methods.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final result = scanForTickViolations(
    // Every file, not just `data/repositories/`: MediaStoresRepository lives at
    // `media_store/data/media_stores_repository.dart`, so a path-shaped filter
    // silently dropped its tick from the vocabulary and reported its consumer
    // as a violation even though it was correctly subscribed.
    repositoryFiles: dartFiles,
    providerFiles: dartFiles,
    relativize: (path) => path.replaceFirst('${Directory.current.path}/', ''),
  );

  test('the scan found the repository, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.tickDeclarationCount, greaterThanOrEqualTo(27));
    expect(result.repositoryReadingProviders, greaterThanOrEqualTo(200));
  });

  test('no provider reads a repository without subscribing to a tick', () {
    expect(
      result.violations,
      isEmpty,
      reason:
          'Change-tick violations. Each provider below calls a repository '
          'method but never subscribes to a change tick, so it will serve a '
          'stale cache after a merge, a bulk delete, or a sync pull.\n\n'
          'Fix by adding, inside the provider body:\n'
          '  ref.invalidateSelfWhen(repository.watchXChanges());\n\n'
          'Pick the tick for the table the query actually READS, which is not '
          'always the tick owned by the repository the method lives on. A '
          'junction read such as BuddyRepository.getDiveIdsForBuddy needs the '
          'DIVES tick, because it goes stale on a cascade delete that never '
          'writes the buddies table.\n\n'
          'If the provider genuinely cannot go stale -- a short-lived '
          'autoDispose read fresh at action time, a value that is a function '
          'or service rather than data, or one where recomputing would re-run '
          'a side effect -- mark it:\n'
          '  // no-tick: <why a stale cache can never render>\n\n'
          '${result.violations.join('\n')}',
    );
  });
}
