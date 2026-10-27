// A flutter test run as a tool (scripts/demo_data/harvest.sh), outside test/.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/harvest/harvester.dart';
import 'src/shape/dive_shape.dart';

/// Step 1 of the demo logbook build (issue #3708), run by
/// scripts/demo_data/harvest.sh: reads real dive logs and writes their
/// anonymous shapes to a folder outside the repository.
///
///   DEMO_HARVEST_OUT      the output folder
///   DEMO_HARVEST_SOURCES  a file listing source paths, one per line
///   DEMO_HARVEST_REPO     the repository root, which the output must avoid
void main() {
  test('harvest dive shapes', () async {
    final env = Platform.environment;
    final out = env['DEMO_HARVEST_OUT'];
    final sources = env['DEMO_HARVEST_SOURCES'];
    final repo = env['DEMO_HARVEST_REPO'];
    expect(out, isNotNull, reason: 'DEMO_HARVEST_OUT');
    expect(sources, isNotNull, reason: 'DEMO_HARVEST_SOURCES');
    expect(repo, isNotNull, reason: 'DEMO_HARVEST_REPO');

    SharedPreferences.setMockInitialValues({});
    final rng = Random.secure();
    final salt = [
      for (var i = 0; i < 16; i++)
        rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final paths = File(sources!)
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final result = await Harvester(
      salt: salt,
      prefs: await SharedPreferences.getInstance(),
    ).harvest(paths);
    await HarvestWriter.write(
      result,
      outDir: out!,
      salt: salt,
      repoRoot: repo!,
    );

    final kinds = <ShapeKind, int>{};
    for (final s in result.shapes) {
      for (final k in s.kinds) {
        kinds[k] = (kinds[k] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print(
      [
        'shapes: ${result.shapes.length}',
        'per source:',
        for (final e in result.perSourceCounts.entries)
          '  ${e.key}: ${e.value}',
        'per kind:',
        for (final e in kinds.entries) '  ${e.key.name}: ${e.value}',
        'skipped:',
        for (final s in result.skipped) '  $s',
      ].join('\n'),
    );
  }, timeout: const Timeout(Duration(hours: 2)));
}
