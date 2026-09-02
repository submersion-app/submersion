import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `database.dart` (and everything it imports) must stay Flutter-free: it
/// runs on the headless isolate and is imported by tools/ scripts. A direct
/// grep of one file cannot see a transitive import, so this walks the graph.
void main() {
  test('database.dart imports nothing from Flutter, transitively', () {
    final root = Directory.current.path;
    final seen = <String>{};
    final queue = <String>['$root/lib/core/database/database.dart'];
    final offenders = <String>[];
    final importPattern = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    expect(
      File(queue.single).existsSync(),
      isTrue,
      reason:
          'the walk must start at the real database.dart; a wrong '
          'working directory would make this test pass vacuously',
    );
    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.startsWith('package:flutter/') ||
            uri.startsWith('package:flutter_')) {
          offenders.add('$path -> $uri');
        } else if (uri.startsWith('package:submersion/')) {
          queue.add('$root/lib/${uri.substring('package:submersion/'.length)}');
        } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
          queue.add(File(path).parent.uri.resolve(uri).toFilePath());
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
