import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// `scripts/filter_trivial_coverage.py` blanks comments and strings in Python
/// before it decides which coverage lines are boilerplate. Its `mask` is a
/// port of [MaskedSource], so a fix made to one of them alone would have the
/// coverage filter and the architecture scanners read the same file
/// differently. This holds the two to the same output on every file in lib/.
void main() {
  test(
    'the coverage filter masks every lib file the way MaskedSource does',
    () {
      final python = _findPython();
      if (python == null) {
        if (Platform.environment['CI'] == 'true') {
          fail('python3 is not installed; the coverage filter needs it');
        }
        markTestSkipped('python3 is not installed');
        return;
      }

      final run = Process.runSync(python, [
        '-c',
        _dumpMasks,
      ], stdoutEncoding: utf8);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final masked = (jsonDecode(run.stdout as String) as Map)
          .cast<String, String>();

      final files =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .map((file) => file.path.replaceAll(r'\', '/'))
              .toList()
            ..sort();
      expect(masked.keys.toList()..sort(), files);

      final differing = [
        for (final path in files)
          if (_differs(
            MaskedSource(File(path).readAsStringSync()).code,
            masked[path]!,
          ))
            path,
      ];
      expect(differing, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Dart blanks UTF-16 code units and Python blanks code points, so a string
/// holding a character outside the Basic Multilingual Plane leaves one more
/// space in Dart. Runs of spaces are compared as one.
final _spaces = RegExp(' +');

bool _differs(String dart, String python) =>
    dart.replaceAll(_spaces, ' ') != python.replaceAll(_spaces, ' ');

String? _findPython() {
  for (final name in ['python3', 'python']) {
    try {
      final version = Process.runSync(name, ['--version']);
      if (version.exitCode == 0) return name;
    } on ProcessException {
      continue;
    }
  }
  return null;
}

/// Prints {path: masked source} for every Dart file under lib/.
const _dumpMasks = r'''
import importlib.util, json, os
spec = importlib.util.spec_from_file_location(
    "filter_trivial_coverage", os.path.join("scripts", "filter_trivial_coverage.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
masked = {}
for root, _, names in os.walk("lib"):
    for name in names:
        if name.endswith(".dart"):
            path = os.path.join(root, name)
            with open(path, encoding="utf-8", newline="") as handle:
                masked[path.replace(os.sep, "/")] = module.mask(handle.read())
print(json.dumps(masked))
''';
