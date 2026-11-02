import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The browser workers under `web/` are compiled with `dart compile js`,
/// apart from Flutter, so everything they reach must be plain Dart: no
/// Flutter, no `dart:ui`, and none of the VM-only libraries the browser
/// lacks. A conditional import resolves to its `dart.library.js_interop`
/// branch, since that is the branch dart2js takes.
void main() {
  const workers = ['web/drift_worker.dart', 'web/compute_worker.dart'];

  final conditional = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]((?:\s*if\s*\([^)]*\)\s*['"][^'"]+['"])*)''',
    multiLine: true,
  );
  final branch = RegExp(r'''if\s*\(([^)]*)\)\s*['"]([^'"]+)['"]''');

  /// The URI dart2js loads for a directive: the `dart.library.js_interop`
  /// branch when one is given, else the default.
  String resolve(RegExpMatch match) {
    var uri = match.group(1)!;
    for (final alt in branch.allMatches(match.group(2) ?? '')) {
      if (alt.group(1)!.trim() == 'dart.library.js_interop') {
        uri = alt.group(2)!;
      }
    }
    return uri;
  }

  for (final worker in workers) {
    test('$worker reaches nothing the browser cannot load', () {
      final root = Directory.current.path;
      final start = '$root/$worker';
      expect(
        File(start).existsSync(),
        isTrue,
        reason: '$worker does not exist; the walk would pass vacuously',
      );
      final offenders = <String>[];
      final seen = <String>{};
      final queue = <String>[start];
      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        if (!seen.add(path)) continue;
        final file = File(path);
        if (!file.existsSync()) continue;
        for (final match in conditional.allMatches(file.readAsStringSync())) {
          final uri = resolve(match);
          if (uri.startsWith('package:flutter') ||
              uri == 'dart:ui' ||
              uri == 'dart:io' ||
              uri == 'dart:ffi' ||
              uri == 'dart:isolate') {
            offenders.add('${path.substring(root.length + 1)} -> $uri');
          } else if (uri.startsWith('package:submersion/')) {
            queue.add(
              '$root/lib/${uri.substring('package:submersion/'.length)}',
            );
          } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
            queue.add(file.parent.uri.resolve(uri).toFilePath());
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}
