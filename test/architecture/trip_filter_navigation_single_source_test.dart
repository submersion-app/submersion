import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Show these trips" goes through `openTripList`, which pushes the trip list
/// so the diver can come back (#3350). Writing the global trip filter and
/// then `go('/trips')` erases the page the link was on, and its back arrow
/// with it.
///
/// The trip list's own filter controls live in lib/features/trips/ and change
/// the filter in place; they are not links, so that folder is exempt.
void main() {
  /// Files outside the trip list permitted to write the filter, with the
  /// reason.
  const allowed = <String, String>{
    'lib/features/explore/presentation/explore_handoff.dart':
        'a search handoff is a deliberate switch to the Trips tab',
  };

  final write = RegExp(r'tripFilterProvider\.notifier');

  test(
    'only openTripList writes the trip filter from outside the trip list',
    () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/features/trips/')) continue;
        if (allowed.containsKey(path)) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (write.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'open the trip list with openTripList (lib/features/trips/'
            'presentation/navigation/open_trip_list.dart) so it is pushed '
            'with a back arrow and the previous filter comes back',
      );
    },
  );

  test('every allowlisted file exists and still writes the filter', () {
    // An allowlist entry that no longer applies is a stale exemption, and a
    // stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        write.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'writes the filter; remove it from the allowlist',
      );
    }
  });

  test('trip pages change their own URL in place', () {
    // A go() on a list pushed by openTripList discards the stack under it,
    // and the way back with it; goInPlace keeps it. Scans the whole trips
    // presentation folder, so a new widget is covered without a list edit.
    const allowedGo = <String, String>{
      'lib/features/trips/presentation/pages/trip_detail_page.dart':
          'the desktop redirect runs only on a page reached by URL, which '
          'has nothing under it to keep',
    };
    final go = RegExp(r'context\.go\(');
    final offenders = <String>[];
    for (final entity in Directory(
      'lib/features/trips/presentation',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowedGo.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (go.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use context.goInPlace so a pushed trip list keeps its way back',
    );
    for (final entry in allowedGo.entries) {
      expect(
        go.hasMatch(File(entry.key).readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'calls context.go; remove it from the allowlist',
      );
    }
  });
}
