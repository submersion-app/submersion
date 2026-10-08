import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dive_date_decode_scanner.dart';

/// Every stored dive time must be decoded as a wall clock flagged UTC, through
/// `wallClockUtcFromMillis` (or `DateTime.fromMillisecondsSinceEpoch(...,
/// isUtc: true)`), never as a plain local `DateTime`.
///
/// `dives.dive_date_time` and `dives.entry_time` hold the dive's wall clock
/// flagged UTC. Buddies, sites, species, media and the checklist linker each
/// decoded them as local on their own (issues #2805, #2808, #2810), which
/// shifts every calendar field by the device's UTC offset and is invisible in
/// UTC CI. Every offender was converted, with no exceptions; this scan is the
/// ratchet.
void main() {
  bool isGenerated(String path) =>
      path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

  test('no file decodes a stored dive time as local time', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      for (final hit in findLocalDiveDateDecodes(entity.readAsStringSync())) {
        offenders.add('$path:$hit');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Decode stored dive times with wallClockUtcFromMillis '
          '(lib/core/util/wall_clock_utc.dart):\n${offenders.join('\n')}',
    );
  });
}
