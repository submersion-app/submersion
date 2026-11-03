import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The compute worker inflates and decrypts payloads a peer wrote, so its
/// list indexing keeps its bounds checks. `-O3` elides the implicit type
/// checks and keeps those; `-O4` adds `--trust-primitives`, which turns a
/// corrupt deflate stream's out-of-range table read into an `undefined`
/// the inflater carries on with, instead of the format error the app
/// expects and the VM vectors in platform_zlib_test.dart prove.
void main() {
  test('the workers are compiled at -O3, keeping bounds checks', () {
    final script = File(
      p.join(Directory.current.path, 'scripts', 'web', 'compile_workers.sh'),
    ).readAsStringSync();
    final compile = RegExp(r'dart compile js\s+(\S+)').allMatches(script);
    expect(compile, isNotEmpty, reason: 'no dart compile js call found');
    for (final call in compile) {
      expect(call.group(1), '-O3');
    }
    expect(
      RegExp(r'^\s*[^#\n]*trust-primitives', multiLine: true).hasMatch(script),
      isFalse,
      reason: 'the flag that drops bounds checks is on a command line',
    );
  });
}
