import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'global_state_scanner.dart';

/// A test that replaces process-wide state has to put it back.
///
/// CI runs many test files in one isolate (issue #2500). A platform singleton,
/// a harness default or a channel mock that one file leaves behind is what the
/// next file starts with, so the failure shows up in a different file from the
/// one that caused it, often in an unrelated change. This scan catches the
/// leak where it is written.
///
/// A restore answers for its own scope: a `tearDown` for the group it is
/// declared in, an `addTearDown` for the test that registers it. Restoring in
/// one group does not excuse a replacement in another. Comments and the
/// contents of strings are not scanned.
///
/// What to write instead:
///
/// * A `*Platform.instance`, `HttpOverrides.global` or `IOOverrides.global`:
///   read the previous value into a variable first, and assign that variable
///   back in `tearDown` or `addTearDown`. Reading the value without assigning
///   it back does not count.
/// * `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled`,
///   `DerivedMetricsScheduler.enabled`, `debugCanShareFiles` or `GoogleFonts.config.allowRuntimeFetching`: call
///   `applyGlobalTestDefaults()` from
///   `test/helpers/global_test_defaults.dart` in `tearDown`.
/// * A mock on the path provider or share channel: call
///   `clearPathAndShareChannelMocks()` from `test/helpers/mock_channels.dart`
///   in `tearDownAll`.
void main() {
  /// Written by `scripts/bundle_tests.py` and never checked in.
  bool isGenerated(String path) => path.startsWith('test/.bundles/');

  /// Files that replace a global on purpose, each with the reason.
  const allowed = <String, String>{
    // Where the defaults are written down. Every other file restores to them.
    'test/helpers/global_test_defaults.dart': 'defines the harness defaults',
    // The harness pins the forwarder once, for the life of the isolate. There
    // is no earlier value to put back: staying in place is what it is for.
    'test/helpers/late_bound_share_platform.dart':
        'pins the share forwarder for the whole isolate',
  };

  Map<String, List<GlobalStateOffence>> scan() {
    final found = <String, List<GlobalStateOffence>>{};
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      final offences = scanForUnrestoredGlobals(
        path,
        entity.readAsStringSync(),
      );
      if (offences.isNotEmpty) found[path] = offences;
    }
    return found;
  }

  test('no test leaves a replaced global behind', () {
    final offenders = [
      for (final entry in scan().entries)
        if (!allowed.containsKey(entry.key)) ...entry.value,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'These assignments replace process-wide state that nothing in the '
          'same file restores. The comment at the top of this test says what '
          'to write instead:\n${offenders.join('\n')}',
    );
  });

  test('every allowlisted file still exists', () {
    for (final path in allowed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every allowlisted file still needs its entry', () {
    final found = scan();
    final stale = [
      for (final path in allowed.keys)
        if (!found.containsKey(path)) path,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'These files no longer replace a global without restoring it. '
          'Remove their entries from the allowlist:\n${stale.join('\n')}',
    );
  });
}
