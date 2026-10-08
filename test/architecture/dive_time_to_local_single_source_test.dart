import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dive_time_to_local_scanner.dart';

/// No dive time is converted to the device's zone with `.toLocal()`.
///
/// Dive times are the dive's wall clock flagged UTC, so they are formatted
/// and compared as they are. The cloud import list converted them for
/// display, which listed every dive shifted by the device's UTC offset
/// (issue #2892); in UTC CI that conversion changes nothing, so no unit test
/// there can catch it coming back. This scan is the ratchet.
///
/// Each allowlisted file says why. A file that no longer converts a dive time
/// fails the second test, so the list only shrinks.
const _allowed = {
  // HealthKit hands over real instants; converting the workout start to the
  // wall clock the diver saw is how it becomes a dive time (issue #2810).
  'lib/features/dive_import/data/services/healthkit_service.dart',
};

void main() {
  bool isGenerated(String path) =>
      path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

  Map<String, List<String>> scan() {
    final hits = <String, List<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      final found = findDiveTimeToLocalCalls(entity.readAsStringSync());
      if (found.isNotEmpty) hits[path] = found;
    }
    return hits;
  }

  test('no file converts a dive time to local time', () {
    final offenders = [
      for (final MapEntry(key: path, value: found) in scan().entries)
        if (!_allowed.contains(path))
          for (final hit in found) '$path:$hit',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Dive times are the wall clock flagged UTC; format them as they '
          'are:\n${offenders.join('\n')}',
    );
  });

  test('every allowlisted file still converts a dive time', () {
    final hits = scan();
    final stale = [
      for (final path in _allowed)
        if (!hits.containsKey(path)) path,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Remove these from the allowlist:\n${stale.join('\n')}',
    );
  });
}
