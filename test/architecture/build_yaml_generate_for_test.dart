import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every generated part file has a builder in build.yaml that runs on it
/// (issue #5136).
///
/// build.yaml limits each code generator to the files that use it, which cuts
/// a cold `build_runner build` by about 4x. The cost is that a new `@riverpod`
/// file, or a Drift database outside `lib/core/database/`, gets no part file
/// and fails to compile with an undefined `_$...` name that says nothing about
/// build.yaml. This guard names the file and the builder to list it under.

/// The folders whose Dart files could hold a generated part.
const _scannedRoots = ['lib', 'test', 'integration_test', 'tool'];

/// A `part 'x.g.dart';` directive, at the start of a line so that a string
/// quoting one does not count.
final _generatedPart = RegExp(r"^part '[^']+\.g\.dart';", multiLine: true);

/// The annotations each builder generates code for.
final _builderAnnotations = <String, RegExp>{
  'riverpod_generator': RegExp(r'^@(riverpod\b|Riverpod\()', multiLine: true),
  'drift_dev': RegExp(r'^@(DriftDatabase|DriftAccessor)\(', multiLine: true),
};

/// The `generate_for` patterns of each builder in a build.yaml [source].
///
/// Reads only the shape this repository uses: a builder key on its own line,
/// then `generate_for:` with one `- pattern` per line. A builder with no
/// `generate_for` is absent from the result and runs on every file.
Map<String, List<String>> generateForPatterns(String source) {
  final builderKey = RegExp(r'^      ([\w:]+):\s*$');
  final listItem = RegExp(r'^\s+-\s+(\S+)\s*$');
  final result = <String, List<String>>{};
  String? builder;
  var inGenerateFor = false;
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('#') || line.trim().isEmpty) continue;
    final key = builderKey.firstMatch(line);
    if (key != null) {
      builder = key.group(1);
      inGenerateFor = false;
      continue;
    }
    if (builder != null && line.trim() == 'generate_for:') {
      inGenerateFor = true;
      result[builder] = [];
      continue;
    }
    final item = listItem.firstMatch(line);
    if (inGenerateFor && item != null) {
      result[builder]!.add(item.group(1)!);
      continue;
    }
    inGenerateFor = false;
  }
  return result;
}

/// Whether the posix [path] matches the build_runner glob [pattern], where
/// `**` spans folders and `*` stays within one.
bool globMatches(String pattern, String path) {
  final buffer = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final char = pattern[i];
    if (char == '*') {
      final isDouble = i + 1 < pattern.length && pattern[i + 1] == '*';
      buffer.write(isDouble ? '.*' : '[^/]*');
      if (isDouble) i++;
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString()).hasMatch(path);
}

/// The builders that [source], a Dart file with a generated part, needs.
Set<String> buildersFor(String source) => {
  for (final entry in _builderAnnotations.entries)
    if (entry.value.hasMatch(source)) entry.key,
};

/// Problems with [patterns] for the generated-part [files], a map from posix
/// path to source. Empty when every file is covered and every pattern is used.
List<String> coverageProblems(
  Map<String, List<String>> patterns,
  Map<String, String> files,
) {
  final problems = <String>[];
  bool covers(String builder, String path) {
    final globs = patterns[builder];
    return globs == null || globs.any((glob) => globMatches(glob, path));
  }

  for (final entry in files.entries) {
    final builders = buildersFor(entry.value);
    if (builders.isEmpty) {
      problems.add(
        '${entry.key} has a .g.dart part but no annotation this guard knows '
        '(${_builderAnnotations.keys.join(', ')}); teach the guard its builder.',
      );
    }
    for (final builder in builders) {
      if (!covers(builder, entry.key)) {
        problems.add(
          '${entry.key} needs $builder, but build.yaml does not list it under '
          '$builder: generate_for, so its part file is never generated.',
        );
      }
    }
  }
  for (final entry in patterns.entries) {
    for (final glob in entry.value) {
      if (!files.keys.any((path) => globMatches(glob, path))) {
        problems.add(
          'build.yaml lists ${entry.key}: generate_for $glob, which matches no '
          'file with a generated part; remove it or fix the path.',
        );
      }
    }
  }
  return problems;
}

Map<String, String> _filesWithGeneratedParts() {
  final files = <String, String>{};
  for (final root in _scannedRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final source = entity.readAsStringSync();
      if (_generatedPart.hasMatch(source)) {
        files[p.posix.joinAll(p.split(entity.path))] = source;
      }
    }
  }
  return files;
}

void main() {
  group('generateForPatterns', () {
    test('reads each builder list and skips builders without one', () {
      const source = '''
# comment
targets:
  \$default:
    builders:
      drift_dev:
        generate_for:
          - lib/core/database/**
          - lib/other.dart
      json_serializable:
        enabled: false
      riverpod_generator:
        generate_for:
          - lib/a_provider.dart
''';
      expect(generateForPatterns(source), {
        'drift_dev': ['lib/core/database/**', 'lib/other.dart'],
        'riverpod_generator': ['lib/a_provider.dart'],
      });
    });
  });

  group('globMatches', () {
    test('** spans folders', () {
      expect(globMatches('lib/core/**', 'lib/core/a/b.dart'), isTrue);
      expect(globMatches('lib/core/**', 'lib/other/b.dart'), isFalse);
    });

    test('* stays within one folder', () {
      expect(globMatches('lib/*.dart', 'lib/a.dart'), isTrue);
      expect(globMatches('lib/*.dart', 'lib/x/a.dart'), isFalse);
    });

    test('a literal path matches only itself', () {
      expect(globMatches('lib/a.dart', 'lib/a.dart'), isTrue);
      expect(globMatches('lib/a.dart', 'lib/a_dart'), isFalse);
    });
  });

  group('coverageProblems', () {
    const riverpodFile = "part 'a.g.dart';\n\n@riverpod\nint a(Ref ref) => 1;";
    const driftFile =
        "part 'db.g.dart';\n\n@DriftDatabase(tables: [])\nclass Db {}";

    test('passes when every file is covered', () {
      expect(
        coverageProblems(
          {
            'drift_dev': ['lib/core/database/**'],
            'riverpod_generator': ['lib/a.dart'],
          },
          {'lib/a.dart': riverpodFile, 'lib/core/database/db.dart': driftFile},
        ),
        isEmpty,
      );
    });

    test('flags a new @riverpod file missing from generate_for', () {
      final problems = coverageProblems(
        {
          'riverpod_generator': ['lib/a.dart'],
        },
        {'lib/a.dart': riverpodFile, 'lib/b.dart': riverpodFile},
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('lib/b.dart needs riverpod_generator'));
    });

    test('flags a Drift database outside the drift_dev glob', () {
      final problems = coverageProblems(
        {
          'drift_dev': ['lib/core/database/**'],
        },
        {
          'lib/core/database/db.dart': driftFile,
          'lib/cache/db.dart': driftFile,
        },
      );
      expect(problems.single, contains('lib/cache/db.dart needs drift_dev'));
    });

    test('flags a pattern left behind by a rename', () {
      final problems = coverageProblems(
        {
          'riverpod_generator': ['lib/a.dart', 'lib/renamed_away.dart'],
        },
        {'lib/a.dart': riverpodFile},
      );
      expect(problems.single, contains('lib/renamed_away.dart'));
    });

    test('flags a generated part with no known annotation', () {
      final problems = coverageProblems({}, {
        'lib/x.dart': "part 'x.g.dart';\n\n@JsonSerializable()\nclass X {}",
      });
      expect(problems.single, contains('no annotation this guard knows'));
    });

    test('treats a builder without generate_for as covering every file', () {
      expect(coverageProblems({}, {'lib/a.dart': riverpodFile}), isEmpty);
    });
  });

  test('build.yaml runs a builder on every file with a generated part', () {
    final patterns = generateForPatterns(File('build.yaml').readAsStringSync());
    final files = _filesWithGeneratedParts();
    // A scan that finds nothing would pass vacuously.
    expect(files, isNotEmpty, reason: 'no file with a .g.dart part was found');
    expect(patterns.keys, containsAll(['drift_dev', 'riverpod_generator']));
    expect(coverageProblems(patterns, files), isEmpty);
  });
}
