import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app's SQL functions are registered inside the browser's database
/// worker, a Dart program compiled apart from Flutter. Everything
/// `app_sql_functions.dart` reaches must therefore be plain Dart: no Flutter,
/// no `dart:ui`, and none of the VM-only libraries the browser lacks. A grep
/// of one file cannot see a transitive import, so this walks the graph.
void main() {
  test('app_sql_functions.dart reaches nothing the worker cannot load', () {
    final root = Directory.current.path;
    final start = '$root/lib/core/database/app_sql_functions.dart';
    expect(
      File(start).existsSync(),
      isTrue,
      reason:
          'the walk must start at the real app_sql_functions.dart; a wrong '
          'working directory would make this test pass vacuously',
    );
    final offenders = <String>[];
    final seen = <String>{};
    final queue = <String>[start];
    final importPattern = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.startsWith('package:flutter') ||
            uri == 'dart:ui' ||
            uri == 'dart:io' ||
            uri == 'dart:ffi' ||
            uri == 'dart:isolate') {
          offenders.add('${path.substring(root.length + 1)} -> $uri');
        } else if (uri.startsWith('package:submersion/')) {
          queue.add('$root/lib/${uri.substring('package:submersion/'.length)}');
        } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
          queue.add(file.parent.uri.resolve(uri).toFilePath());
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
